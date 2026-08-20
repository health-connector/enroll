# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/data_anonymization/anonymized_data'
require_relative '../../../lib/data_anonymization/verifier'

RSpec.describe DataAnonymizer::Verifier, dbclean: :around_each do
  let(:db_double) { instance_double(Mongo::Database, name: 'test_db', collection_names: []) }
  let(:client_double) { instance_double(Mongo::Client, database: db_double) }

  before do
    allow(Mongoid).to receive(:default_client).and_return(client_double)
  end

  subject(:verifier) { described_class.new }

  # @!group Generated email pattern — tests for GENERATED_EMAIL_PATTERN

  describe 'GENERATED_EMAIL_PATTERN' do
    subject(:pattern) { described_class::GENERATED_EMAIL_PATTERN }

    it 'matches exampleanonymizer.com addresses' do
      expect('user42@exampleanonymizer.com').to match(pattern)
    end

    it 'matches testanonymizer.com addresses' do
      expect('user1@testanonymizer.com').to match(pattern)
    end

    it 'does not match real domain addresses' do
      expect('john.doe@gmail.com').not_to match(pattern)
      expect('user@example.com').not_to match(pattern)
      expect('test@ideacrew.com').not_to match(pattern)
    end

    it 'does not match partial domain matches' do
      expect('user@notexampleanonymizer.com').not_to match(pattern)
    end
  end

  # @!group Initialize — initialization tests

  describe '#initialize' do
    it 'defaults to smoke mode' do
      expect(verifier.instance_variable_get(:@mode)).to eq(:smoke)
    end

    it 'accepts audit mode' do
      v = described_class.new(mode: :audit)
      expect(v.instance_variable_get(:@mode)).to eq(:audit)
    end

    it 'stores prehash_map and hmac_key' do
      map = { people: { 'abc' => 'deadbeef' } }
      v = described_class.new(prehash_map: map, hmac_key: 'secret')
      expect(v.instance_variable_get(:@prehash_map)).to eq(map)
      expect(v.instance_variable_get(:@hmac_key)).to eq('secret')
    end

    it 'stores run_id for out-of-process verification' do
      v = described_class.new(run_id: 'uuid-1234')
      expect(v.instance_variable_get(:@run_id)).to eq('uuid-1234')
    end
  end

  # @!group build_result — helper result formatting tests

  describe '#build_result' do
    subject(:result) { verifier.send(:build_result, 'People (people)', 1000, [], '') }

    it 'marks passed true when issues are empty' do
      expect(result[:passed]).to be true
    end

    it 'marks passed false when issues are present' do
      r = verifier.send(:build_result, 'People', 100, ['1 real email found'], '')
      expect(r[:passed]).to be false
    end

    it 'includes the collection name' do
      expect(result[:collection]).to eq('People (people)')
    end

    it 'reports None when there are no issues' do
      expect(result[:issues]).to eq('None')
    end
  end

  # @!group check_name_dob_prehash — canonical prehash verification tests

  describe '#check_name_dob_prehash' do
    context 'when prehash_map or hmac_key is missing' do
      it 'passes (skipped) with a prominent SKIPPED note in samples when both are nil' do
        result = verifier.send(:check_name_dob_prehash)
        expect(result[:passed]).to be true
        expect(result[:issues]).to eq('None')
        expect(result[:samples]).to include('SKIPPED')
        expect(result[:samples]).to include('name+DOB mutation NOT verified')
      end

      it 'emits a WARNING log line when skipped' do
        expect(Rails.logger).to receive(:info).with(a_string_including('WARNING'))
        verifier.send(:check_name_dob_prehash)
      end

      it 'passes (skipped) when only hmac_key is nil' do
        v = described_class.new(mode: :audit, prehash_map: { people: {} }, hmac_key: nil)
        result = v.send(:check_name_dob_prehash)
        expect(result[:passed]).to be true
        expect(result[:samples]).to include('SKIPPED')
      end

      it 'passes (skipped) when only prehash_map is nil' do
        v = described_class.new(mode: :audit, prehash_map: nil, hmac_key: 'somekey')
        result = v.send(:check_name_dob_prehash)
        expect(result[:passed]).to be true
        expect(result[:samples]).to include('SKIPPED')
      end
    end

    context 'when prehash_map and hmac_key are present' do
      let(:hmac_key) { 'test_key_abcdef1234567890' }
      let(:canon) { 'alice|smith|1 main st|boston|6175550000' }
      let(:stored_hmac) { OpenSSL::HMAC.hexdigest('SHA256', hmac_key, canon) }
      let(:fake_id) { BSON::ObjectId.new }

      let(:prehash_map) { { people: { fake_id.to_s => stored_hmac } } }

      subject(:audit_verifier) do
        described_class.new(mode: :audit, prehash_map: prehash_map, hmac_key: hmac_key)
      end

      before do
        collection_double = instance_double(Mongo::Collection)
        view_double = instance_double(Mongo::Collection::View)
        allow(db_double).to receive(:collection_names).and_return(['people'])
        allow(db_double).to receive(:[]).with(:people).and_return(collection_double)
        allow(collection_double).to receive(:find).and_return(view_double)
        allow(view_double).to receive(:first).and_return(doc_after)
      end

      context 'when the record was changed (HMAC differs)' do
        let(:doc_after) do
          {
            '_id' => fake_id,
            'first_name' => 'Bob',
            'last_name' => 'Jones',
            'addresses' => [{ 'address_1' => '99 Fake Ave', 'city' => 'Springfield' }],
            'phones' => [{ 'area_code' => '800', 'number' => '1234567' }]
          }
        end

        it 'passes' do
          result = audit_verifier.send(:check_name_dob_prehash)
          expect(result[:passed]).to be true
          expect(result[:issues]).to eq('None')
        end
      end

      context 'when the record was NOT changed (HMAC matches)' do
        # Return the same doc that produced the stored prehash
        let(:doc_after) do
          {
            '_id' => fake_id,
            'first_name' => 'Alice',
            'last_name' => 'Smith',
            'addresses' => [{ 'address_1' => '1 Main St', 'city' => 'Boston' }],
            'phones' => [{ 'area_code' => '617', 'number' => '5550000' }]
          }
        end

        it 'fails' do
          result = audit_verifier.send(:check_name_dob_prehash)
          expect(result[:passed]).to be false
          expect(result[:issues]).to include('Unchanged canonical payload')
        end
      end
    end
  end

  # @!group Canonical payload helpers — canonicalization helper tests

  describe '#canonical_person_payload' do
    let(:doc) do
      {
        'first_name' => ' Alice ',
        'last_name' => 'SMITH',
        'addresses' => [{ 'address_1' => '1 Main St', 'city' => 'Boston' }],
        'phones' => [{ 'area_code' => '617', 'number' => '5550000' }]
      }
    end

    it 'strips and downcases all components' do
      result = verifier.send(:canonical_person_payload, doc)
      expect(result).to eq('alice|smith|1 main st|boston|6175550000')
    end

    it 'handles missing phones gracefully' do
      doc_no_phone = doc.merge('phones' => [])
      expect { verifier.send(:canonical_person_payload, doc_no_phone) }.not_to raise_error
    end

    it 'handles missing addresses gracefully' do
      doc_no_addr = doc.merge('addresses' => [])
      expect { verifier.send(:canonical_person_payload, doc_no_addr) }.not_to raise_error
    end
  end

  describe '#canonical_org_payload' do
    it 'combines legal name and ACH fields' do
      doc = {
        'legal_name' => 'Acme Corp',
        'broker_agency_profile' => {
          'ach_routing_number' => '021000021',
          'ach_account_number' => '9876543210'
        }
      }
      expect(verifier.send(:canonical_org_payload, doc)).to eq('acme corp|021000021|9876543210')
    end

    it 'handles missing broker_agency_profile' do
      doc = { 'legal_name' => 'No Broker Corp' }
      expect(verifier.send(:canonical_org_payload, doc)).to eq('no broker corp||')
    end
  end

  describe '#canonical_bs_org_payload' do
    it 'combines legal name and all profile ACH fields' do
      doc = {
        'legal_name' => 'BS Corp',
        'profiles' => [
          { 'ach_routing_number' => '111000025', 'ach_account_number' => '12345' }
        ]
      }
      expect(verifier.send(:canonical_bs_org_payload, doc)).to eq('bs corp|111000025:12345')
    end
  end

  # @!group write_csv_report — CSV report output tests

  describe '#write_csv_report' do
    let(:results) do
      [
        { collection: 'People (people)', total: 100, passed: true, issues: 'None', samples: '' },
        { collection: 'Users (users)',   total: 50,  passed: false, issues: '3 real emails', samples: 'a@b.com' }
      ]
    end

    it 'writes a CSV and returns the path' do
      path = verifier.send(:write_csv_report, results)
      expect(File).to exist(path)
      content = CSV.read(path, headers: true)
      expect(content.length).to eq(2)
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end

  # @!group SKIP_FIELDS — constant membership tests

  describe 'SKIP_FIELDS' do
    subject(:skip_fields) { described_class::SKIP_FIELDS }

    it 'is frozen' do
      expect(skip_fields).to be_frozen
    end

    it 'includes _id to avoid scanning Mongo ObjectId strings' do
      expect(skip_fields).to include('_id')
    end

    it 'includes encrypted_ssn to avoid false positives from ciphertext' do
      expect(skip_fields).to include('encrypted_ssn')
    end

    it 'includes fein — 9-digit EIN intentionally left unchanged per policy' do
      expect(skip_fields).to include('fein')
    end

    it 'includes ach_routing_number — ABA routing numbers are always 9 digits and validated separately' do
      expect(skip_fields).to include('ach_routing_number')
    end

    it 'includes npn and corporate_npn — public broker NPNs intentionally preserved by the runner' do
      expect(skip_fields).to include('npn', 'corporate_npn')
    end

    it 'includes content — free-text Comment/Announcement field may contain incidental 9-digit tokens' do
      expect(skip_fields).to include('content')
    end

    it 'includes dba — organization doing-business-as name intentionally preserved per policy' do
      expect(skip_fields).to include('dba')
    end

    it 'includes versions — inline mongoid-history snapshot array is not scanned for SSN patterns' do
      expect(skip_fields).to include('versions')
    end
  end

  # @!group doc_strings — recursive string extractor tests

  describe '#doc_strings' do
    it 'yields plain string values' do
      expect(verifier.send(:doc_strings, 'hello').to_a).to eq(['hello'])
    end

    it 'recurses into nested hashes and yields leaf strings' do
      doc = { 'name' => 'Alice', 'address' => { 'city' => 'Boston' } }
      expect(verifier.send(:doc_strings, doc).to_a).to contain_exactly('Alice', 'Boston')
    end

    it 'recurses into arrays' do
      doc = { 'emails' => [{ 'address' => 'a@b.com' }, { 'address' => 'x@y.com' }] }
      expect(verifier.send(:doc_strings, doc).to_a).to contain_exactly('a@b.com', 'x@y.com')
    end

    it 'skips the fein key so 9-digit EINs are not yielded' do
      doc = { 'fein' => '123456789', 'legal_name' => 'Acme' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Acme'])
    end

    it 'skips ach_routing_number so valid 9-digit routing numbers are not yielded' do
      doc = { 'ach_routing_number' => '021000021', 'name' => 'Bank' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Bank'])
    end

    it 'skips encrypted_ssn to avoid ciphertext false positives' do
      doc = { 'encrypted_ssn' => 'AaBbCcDd123456789', 'first_name' => 'Bob' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Bob'])
    end

    it 'skips npn and corporate_npn so broker NPNs are not yielded' do
      doc = { 'npn' => '120002398', 'corporate_npn' => '216179133', 'name' => 'Agency' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Agency'])
    end

    it 'skips content so operator-entered narrative text is not scanned for SSN patterns' do
      doc = { 'comments' => [{ 'content' => 'received payment 120002398 from group' }], 'hbx_id' => '42' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['42'])
    end

    it 'skips dba so numeric doing-business-as names are not yielded' do
      doc = { 'dba' => '125000024', 'legal_name' => 'Acme Corp' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Acme Corp'])
    end

    it 'skips the versions key so inline mongoid-history snapshots are not scanned' do
      doc = {
        'first_name' => 'Alice',
        'versions' => [
          { 'phones' => [{ 'full_phone_number' => '216179133' }] },
          { 'broker_agency_profile' => { 'ach_account_number' => '163674734' } }
        ]
      }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['Alice'])
    end

    it 'returns an enumerator when no block is given' do
      expect(verifier.send(:doc_strings, 'test')).to be_a(Enumerator)
    end

    it 'ignores non-string scalar values (integers, booleans, nil)' do
      doc = { 'count' => 42, 'active' => true, 'note' => nil, 'tag' => 'yes' }
      expect(verifier.send(:doc_strings, doc).to_a).to eq(['yes'])
    end
  end

  # @!group Unredacted filename pattern - tests for UNREDACTED_FILENAME_PATTERN

  describe 'UNREDACTED_FILENAME_PATTERN' do
    subject(:pattern) { described_class::UNREDACTED_FILENAME_PATTERN }

    it 'matches a body with a real filename parameter' do
      expect('href=/x?filename=EmployerInvoiceAvailable.pdf&disposition=inline').to match(pattern)
    end

    it 'does not match a redacted filename parameter' do
      expect('href=/x?filename=document-redacted&disposition=inline').not_to match(pattern)
    end
  end

  # @!group check_inbox_messages - residual filename detection

  describe '#check_inbox_messages' do
    let(:people_collection) { instance_double(Mongo::Collection) }
    let(:orgs_collection) { instance_double(Mongo::Collection) }
    let(:bs_orgs_collection) { instance_double(Mongo::Collection) }

    before do
      allow(db_double).to receive(:[]).with(:people).and_return(people_collection)
      allow(db_double).to receive(:[]).with(:organizations).and_return(orgs_collection)
      allow(db_double).to receive(:[]).with(:benefit_sponsors_organizations_organizations).and_return(bs_orgs_collection)
      allow(orgs_collection).to receive(:count_documents).and_return(0)
      allow(bs_orgs_collection).to receive(:count_documents).and_return(0)
    end

    def stub_people_sample(doc)
      view = instance_double(Mongo::Collection::View)
      allow(people_collection).to receive(:count_documents).and_return(1)
      allow(people_collection).to receive(:find).and_return(view)
      allow(view).to receive(:projection).and_return(view)
      allow(view).to receive(:limit).and_return([doc])
    end

    it 'passes when sampled message bodies contain only redacted filenames' do
      stub_people_sample('inbox' => { 'messages' => [{ 'body' => 'a?filename=document-redacted' }] })
      result = verifier.send(:check_inbox_messages)
      expect(result[:passed]).to be true
    end

    it 'fails when a sampled message body still contains a real filename' do
      stub_people_sample('inbox' => { 'messages' => [{ 'body' => 'a?filename=EmployerInvoice.pdf' }] })
      result = verifier.send(:check_inbox_messages)
      expect(result[:passed]).to be false
      expect(result[:issues]).to include('people')
    end

    it 'checks broker agency and hbx profile inbox paths on organizations' do
      allow(people_collection).to receive(:count_documents).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'employer_profile.inbox.messages.0' => { '$exists' => true } }).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'broker_agency_profile.inbox.messages.0' => { '$exists' => true } }).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'hbx_profile.inbox.messages.0' => { '$exists' => true } }).and_return(0)
      verifier.send(:check_inbox_messages)
    end
  end

  # @!group check_document_identifiers - residual S3 identifier detection

  describe '#check_document_identifiers' do
    let(:people_collection) { instance_double(Mongo::Collection) }
    let(:orgs_collection) { instance_double(Mongo::Collection) }

    before do
      allow(db_double).to receive(:[]).with(:people).and_return(people_collection)
      allow(db_double).to receive(:[]).with(:organizations).and_return(orgs_collection)
      allow(orgs_collection).to receive(:count_documents).and_return(0)
    end

    it 'passes when no embedded documents carry a real identifier' do
      allow(people_collection).to receive(:count_documents).and_return(0)
      result = verifier.send(:check_document_identifiers)
      expect(result[:passed]).to be true
    end

    it 'fails when embedded documents still hold non anonymized identifiers' do
      allow(people_collection).to receive(:count_documents).and_return(2)
      result = verifier.send(:check_document_identifiers)
      expect(result[:passed]).to be false
      expect(result[:issues]).to include('people')
    end

    it 'checks the org level and broker agency document paths on organizations' do
      allow(people_collection).to receive(:count_documents).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'documents.0' => { '$exists' => true } }).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'employer_profile.documents.0' => { '$exists' => true } }).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with({ 'broker_agency_profile.documents.0' => { '$exists' => true } }).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with(hash_including('documents' => anything)).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with(hash_including('employer_profile.documents' => anything)).and_return(0)
      expect(orgs_collection).to receive(:count_documents).with(hash_including('broker_agency_profile.documents' => anything)).and_return(0)
      verifier.send(:check_document_identifiers)
    end

    it 'skips the benefit sponsors documents collection when it is absent' do
      allow(people_collection).to receive(:count_documents).and_return(0)
      expect(db_double).not_to receive(:[]).with(:benefit_sponsors_documents_documents)
      verifier.send(:check_document_identifiers)
    end

    it 'excludes issuer profile documents from the benefit sponsors check' do
      bs_collection = instance_double(Mongo::Collection)
      allow(db_double).to receive(:collection_names).and_return(['benefit_sponsors_documents_documents'])
      allow(db_double).to receive(:[]).with(:benefit_sponsors_documents_documents).and_return(bs_collection)
      allow(people_collection).to receive(:count_documents).and_return(0)
      expect(bs_collection).to receive(:count_documents).with(
        hash_including('documentable_type' => { '$ne' => 'BenefitSponsors::Organizations::IssuerProfile' })
      ).twice.and_return(0)
      verifier.send(:check_document_identifiers)
    end
  end
end
