# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/data_anonymization/anonymized_data'
require_relative '../../../lib/data_anonymization/verifier'
# Loaded so the collection constants can be cross-checked.
require_relative '../../../lib/data_anonymization/runner'

RSpec.describe DataAnonymizer::Verifier, dbclean: :around_each do
  let(:db_double) { instance_double(Mongo::Database, name: 'test_db', collection_names: []) }
  let(:client_double) { instance_double(Mongo::Client, database: db_double) }

  before do
    allow(Mongoid).to receive(:default_client).and_return(client_double)
  end

  subject(:verifier) { described_class.new }

  describe '#log' do
    it 'logs with the class tag and does not duplicate messages on stdout' do
      allow(Rails.env).to receive(:test?).and_return(false)
      expect(Rails.logger).to receive(:tagged).with(described_class.name).and_call_original
      expect(Rails.logger).to receive(:info).with('Checked 5 records')

      expect { verifier.send(:log, 'Checked 5 records') }.not_to output.to_stdout
    end
  end

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

  # @!group identity prehash - each employer name proven individually

  describe '#check_identity_prehash' do
    let(:hmac_key) { 'identity_key_123456' }
    let(:fake_id)  { BSON::ObjectId.new }

    def digests_for(values)
      values.each_with_index.map { |v, i| v.presence && OpenSSL::HMAC.hexdigest('SHA256', hmac_key, "#{fake_id}:#{i}:#{v}") }
    end

    def verifier_for(doc_after, stored_values)
      v = described_class.new(
        mode: :audit,
        identity_prehash_map: { organizations: { fake_id.to_s => digests_for(stored_values) } },
        hmac_key: hmac_key
      )
      collection_double = instance_double(Mongo::Collection)
      view_double = instance_double(Mongo::Collection::View)
      allow(db_double).to receive(:collection_names).and_return(['organizations'])
      allow(db_double).to receive(:[]).with(:organizations).and_return(collection_double)
      allow(collection_double).to receive(:find).with('_id' => { '$in' => [fake_id] }).and_return(view_double)
      allow(view_double).to receive(:batch_size).and_return(view_double)
      allow(view_double).to receive(:each).and_yield(doc_after.merge('_id' => fake_id))
      v
    end

    it 'passes when every name changed' do
      after = { 'legal_name' => 'nienow inc', 'dba' => 'orn llc', 'home_page' => 'http://roob.info' }
      v = verifier_for(after, ['real co', 'real trading', 'http://real.com'])
      expect(v.send(:check_identity_prehash)[:passed]).to be true
    end

    it 'catches a dba left behind while legal_name changed' do
      after = { 'legal_name' => 'nienow inc', 'dba' => 'real trading', 'home_page' => 'http://roob.info' }
      v = verifier_for(after, ['real co', 'real trading', 'http://real.com'])
      result = v.send(:check_identity_prehash)
      expect(result[:passed]).to be false
      expect(result[:issues]).to match(/Unchanged dba/)
    end

    it 'catches a home_page left behind' do
      after = { 'legal_name' => 'nienow inc', 'dba' => 'orn llc', 'home_page' => 'http://real.com' }
      v = verifier_for(after, ['real co', 'real trading', 'http://real.com'])
      expect(v.send(:check_identity_prehash)[:issues]).to match(/Unchanged home_page/)
    end

    it 'names every field that was left behind' do
      after = { 'legal_name' => 'real co', 'dba' => 'real trading', 'home_page' => 'http://roob.info' }
      v = verifier_for(after, ['real co', 'real trading', 'http://real.com'])
      expect(v.send(:check_identity_prehash)[:issues]).to match(/legal_name,dba/)
    end

    it 'ignores a field the record never held' do
      after = { 'legal_name' => 'nienow inc', 'dba' => '', 'home_page' => '' }
      v = verifier_for(after, ['real co', '', ''])
      expect(v.send(:check_identity_prehash)[:passed]).to be true
    end

    it 'fails rather than passing when the digests have expired' do
      v = described_class.new(mode: :audit, identity_prehash_map: {}, hmac_key: hmac_key, run_id: 'expired-run')
      allow(v).to receive(:wrong_hmac_key?).and_return(false)
      result = v.send(:check_identity_prehash)
      expect(result[:passed]).to be false
      expect(result[:issues]).to match(/No identity digests stored/)
    end

    it 'marks itself skipped without credentials rather than passing' do
      result = verifier.send(:check_identity_prehash)
      expect(result[:skipped]).to be true
      expect(result[:samples]).to include('Employer naming NOT verified')
    end
  end

  # @!group hmac key validation

  describe '#wrong_hmac_key?' do
    let(:real_key) { 'the_key_the_run_used' }
    let(:fingerprint) do
      OpenSSL::HMAC.hexdigest('SHA256', real_key, DataAnonymizer::Runner::KEY_FINGERPRINT_MESSAGE)
    end

    def verifier_with_key(supplied)
      v = described_class.new(mode: :audit, hmac_key: supplied, run_id: 'run-1')
      collection_double = instance_double(Mongo::Collection)
      view_double = instance_double(Mongo::Collection::View)
      allow(db_double).to receive(:collection_names).and_return(['data_anonymizer_prehashes'])
      allow(db_double).to receive(:[]).with(:data_anonymizer_prehashes).and_return(collection_double)
      allow(collection_double).to receive(:find).and_return(view_double)
      allow(view_double).to receive(:first).and_return({ 'digest' => fingerprint })
      v
    end

    it 'accepts the key the run actually used' do
      expect(verifier_with_key(real_key).send(:wrong_hmac_key?)).to be false
    end

    it 'rejects a mistyped key instead of reading every digest as changed' do
      expect(verifier_with_key('a_different_key').send(:wrong_hmac_key?)).to be true
    end

    it 'fails the zip check outright when the key is wrong' do
      v = verifier_with_key('a_different_key')
      v.instance_variable_set(:@zip_prehash_map, { people: { 'x' => ['d'] } })
      result = v.send(:check_zip_prehash)
      expect(result[:passed]).to be false
      expect(result[:issues]).to match(/does not match the key/)
    end

    it 'stays quiet for older runs that stored no fingerprint' do
      v = described_class.new(mode: :audit, hmac_key: 'anything', run_id: 'run-1')
      allow(db_double).to receive(:collection_names).and_return([])
      expect(v.send(:wrong_hmac_key?)).to be false
    end
  end

  # @!group prehash collection resolution

  describe 'PREHASH_COLLECTIONS' do
    it 'resolves bs_organizations to its real collection' do
      expect(described_class::PREHASH_COLLECTIONS[:bs_organizations])
        .to eq(:benefit_sponsors_organizations_organizations)
    end

    it 'stays in step with the runner constant it mirrors' do
      expect(described_class::PREHASH_COLLECTIONS[:plan_design_organizations])
        .to eq(DataAnonymizer::Runner::PLAN_DESIGN_ORG_COLLECTION)
    end

    it 'resolves every key to a name the database would recognise' do
      described_class::PREHASH_COLLECTIONS.each_value do |collection|
        expect(collection.to_s).to match(/\A[a-z_]+\z/)
      end
    end
  end

  # @!group employer zip bound - unchanged employer zips are allowed, but counted

  describe '#employer_zip_issues' do
    def verifier_with(skipped)
      described_class.new(mode: :audit, hmac_key: 'k', geo_swap_skipped: skipped)
    end

    it 'allows unchanged employer zips up to the tally the run reported' do
      expect(verifier_with(5).send(:employer_zip_issues, 5)).to be_empty
    end

    it 'allows fewer unchanged than were skipped' do
      expect(verifier_with(5).send(:employer_zip_issues, 2)).to be_empty
    end

    it 'fails when more are unchanged than the run skipped' do
      issues = verifier_with(2).send(:employer_zip_issues, 40)
      expect(issues.first).to match(/40 employer zips unchanged, more than the 2/)
    end

    it 'counts plan design organizations as employer zips too' do
      expect(described_class::EMPLOYER_ZIP_COLLECTIONS)
        .to include(:sponsored_benefits_organizations_plan_design_organizations)
    end

    it 'catches a wholesale failure where nothing was swapped' do
      issues = verifier_with(0).send(:employer_zip_issues, 300)
      expect(issues).not_to be_empty
    end

    it 'fails when zips are unchanged but no tally was recorded' do
      issues = described_class.new(mode: :audit, hmac_key: 'k').send(:employer_zip_issues, 7)
      expect(issues.first).to match(/no skip tally recorded/)
    end

    it 'stays quiet when nothing is unchanged and no tally exists' do
      expect(described_class.new(mode: :audit, hmac_key: 'k').send(:employer_zip_issues, 0)).to be_empty
    end
  end

  # @!group overall status - pass, fail and incomplete

  describe '#overall_status' do
    def result(passed:, skipped: false)
      { collection: 'x', total: 1, passed: passed, skipped: skipped, issues: 'None', samples: '' }
    end

    it 'is pass when every check ran and passed' do
      expect(verifier.send(:overall_status, [result(passed: true), result(passed: true)])).to eq(:pass)
    end

    it 'is fail when any check failed' do
      expect(verifier.send(:overall_status, [result(passed: true), result(passed: false)])).to eq(:fail)
    end

    it 'is incomplete when nothing failed but a check was skipped' do
      results = [result(passed: true), result(passed: true, skipped: true)]
      expect(verifier.send(:overall_status, results)).to eq(:incomplete)
    end

    it 'reports fail ahead of incomplete when both are present' do
      results = [result(passed: false), result(passed: true, skipped: true)]
      expect(verifier.send(:overall_status, results)).to eq(:fail)
    end

    it 'never lets an incomplete run read as safe to share' do
      expect(verifier.send(:status_line, :incomplete)).to include('INCOMPLETE')
      expect(verifier.send(:status_line, :incomplete)).not_to include('Safe to dump')
    end

    it 'tells the operator the digests expire' do
      expect(verifier.send(:status_line, :incomplete)).to include('7 days')
    end
  end

  # @!group check_zip_prehash - geographic swap verification tests

  describe '#load_prehash_map_from_ttl' do
    let(:run_id) { 'run-abc-123' }
    let(:person_id) { BSON::ObjectId.new }
    let(:census_id) { BSON::ObjectId.new }

    let(:rows) do
      [
        { 'collection' => 'people', 'record_id' => person_id, 'scope' => 'zip_prehash', 'digest' => %w[aaa] },
        { 'collection' => 'census_members', 'record_id' => census_id, 'scope' => 'zip_prehash', 'digest' => %w[bbb] }
      ]
    end

    before do
      collection_double = instance_double(Mongo::Collection)
      allow(db_double).to receive(:collection_names).and_return(['data_anonymizer_prehashes'])
      allow(db_double).to receive(:[]).with(:data_anonymizer_prehashes).and_return(collection_double)
      allow(collection_double).to receive(:find)
        .with('run_id' => run_id, 'scope' => 'zip_prehash')
        .and_return(rows)
    end

    it 'groups digests by their own collection, not by the requested scope' do
      map = verifier.send(:load_prehash_map_from_ttl, run_id, 'zip_prehash')
      expect(map.keys).to contain_exactly(:people, :census_members)
    end

    it 'keys each record by its id' do
      map = verifier.send(:load_prehash_map_from_ttl, run_id, 'zip_prehash')
      expect(map[:people][person_id.to_s]).to eq(%w[aaa])
      expect(map[:census_members][census_id.to_s]).to eq(%w[bbb])
    end
  end

  describe '#check_zip_prehash' do
    let(:hmac_key) { 'test_key_abcdef1234567890' }
    let(:fake_id)  { BSON::ObjectId.new }

    def digest_for(index, zip)
      OpenSSL::HMAC.hexdigest('SHA256', hmac_key, "#{fake_id}:#{index}:#{zip}")
    end

    # +stored_zips+ is the pre-run zip per address slot, in stored order.
    def verifier_for(doc_after, stored_zips)
      digests = Array(stored_zips).each_with_index.map { |zip, index| zip.presence && digest_for(index, zip) }
      v = described_class.new(
        mode: :audit,
        zip_prehash_map: { people: { fake_id.to_s => digests } },
        hmac_key: hmac_key
      )
      collection_double = instance_double(Mongo::Collection)
      view_double = instance_double(Mongo::Collection::View)
      allow(db_double).to receive(:collection_names).and_return(['people'])
      allow(db_double).to receive(:[]).with(:people).and_return(collection_double)
      allow(collection_double).to receive(:find).and_return(view_double)
      allow(view_double).to receive(:batch_size).and_return(view_double)
      allow(view_double).to receive(:each).and_yield(doc_after)
      v
    end

    context 'when credentials are missing' do
      it 'passes as skipped rather than blocking the sentinel' do
        result = verifier.send(:check_zip_prehash)
        expect(result[:passed]).to be true
        expect(result[:samples]).to include('SKIPPED')
        expect(result[:samples]).to include('Zip mutation NOT verified')
      end

      it 'emits a WARNING so the gap is visible' do
        expect(Rails.logger).to receive(:info).with(a_string_including('WARNING'))
        verifier.send(:check_zip_prehash)
      end
    end

    context 'when credentials are supplied but no digests were stored' do
      it 'fails rather than reporting a pass' do
        v = described_class.new(
          mode: :audit, zip_prehash_map: { people: {} }, hmac_key: hmac_key, run_id: 'stale-run-id'
        )
        result = v.send(:check_zip_prehash)
        expect(result[:passed]).to be false
        expect(result[:issues]).to match(/No zip digests stored/)
      end

      it 'still passes for an in-run verification, which supplies no run_id' do
        v = described_class.new(mode: :audit, zip_prehash_map: { people: {} }, hmac_key: hmac_key)
        expect(v.send(:check_zip_prehash)[:passed]).to be true
      end
    end

    context 'when the zip changed' do
      it 'passes' do
        v = verifier_for({ '_id' => fake_id, 'addresses' => [{ 'zip' => '02108' }] }, ['02101'])
        result = v.send(:check_zip_prehash)
        expect(result[:passed]).to be true
      end
    end

    context 'when the zip did not change' do
      it 'fails' do
        v = verifier_for({ '_id' => fake_id, 'addresses' => [{ 'zip' => '02101' }] }, ['02101'])
        result = v.send(:check_zip_prehash)
        expect(result[:passed]).to be false
        expect(result[:issues]).to match(/Unchanged zip/)
      end
    end

    context 'when a record has several addresses and none changed' do
      it 'fails' do
        v = verifier_for(
          { '_id' => fake_id, 'addresses' => [{ 'zip' => '02101' }, { 'zip' => '02110' }] },
          %w[02101 02110]
        )
        expect(v.send(:check_zip_prehash)[:passed]).to be false
      end
    end

    context 'when one address changed but a sibling kept its real zip' do
      # Each slot is compared on its own.
      it 'fails and names the stale slot' do
        v = verifier_for(
          { '_id' => fake_id, 'addresses' => [{ 'zip' => '02199' }, { 'zip' => '02110' }] },
          %w[02101 02110]
        )
        result = v.send(:check_zip_prehash)
        expect(result[:passed]).to be false
        expect(result[:issues]).to match(/slot\(s\) 1/)
      end

      it 'passes only once every slot has moved' do
        v = verifier_for(
          { '_id' => fake_id, 'addresses' => [{ 'zip' => '02199' }, { 'zip' => '02120' }] },
          %w[02101 02110]
        )
        expect(v.send(:check_zip_prehash)[:passed]).to be true
      end
    end

    context 'when a zip was cleared instead of replaced' do
      it 'fails rather than counting the blank as a successful change' do
        v = verifier_for({ '_id' => fake_id, 'addresses' => [{ 'zip' => '' }] }, ['02101'])
        result = v.send(:check_zip_prehash)
        expect(result[:passed]).to be false
        expect(result[:issues]).to match(/cleared rather than replaced/)
      end

      it 'reports the cleared slot separately from an unchanged one' do
        v = verifier_for(
          { '_id' => fake_id, 'addresses' => [{ 'zip' => '' }, { 'zip' => '02110' }] },
          %w[02101 02110]
        )
        issues = v.send(:check_zip_prehash)[:issues]
        expect(issues).to match(/cleared rather than replaced/)
        expect(issues).to match(/Unchanged zip/)
      end
    end

    context 'when a slot never held a zip' do
      it 'does not treat the blank slot as stale' do
        v = verifier_for(
          { '_id' => fake_id, 'addresses' => [{ 'zip' => '02199' }, { 'zip' => '' }] },
          ['02101', '']
        )
        expect(v.send(:check_zip_prehash)[:passed]).to be true
      end
    end
  end

  # @!group check_name_dob_prehash — canonical prehash verification tests

  describe '#each_prehash_record' do
    it 'fetches multiple records together while keeping batches bounded' do
      stub_const('DataAnonymizer::Verifier::PREHASH_BATCH_SIZE', 2)
      documents = Array.new(3) { { '_id' => BSON::ObjectId.new } }
      digests = documents.to_h { |doc| [doc['_id'].to_s, ['digest']] }
      collection = instance_double(Mongo::Collection)
      allow(db_double).to receive(:[]).with(:people).and_return(collection)
      documents.each_slice(2) do |batch|
        cursor = instance_double(Mongo::Collection::View)
        expect(collection).to receive(:find).with('_id' => { '$in' => batch.map { |doc| doc['_id'] } }).once.and_return(cursor)
        allow(cursor).to receive(:batch_size).with(2).and_return(batch)
      end

      found = []
      verifier.send(:each_prehash_record, 'people', digests) { |doc, stored| found << [doc, stored] }
      expect(found).to eq(documents.map { |doc| [doc, ['digest']] })
    end

    it 'looks up a record whose id is not an ObjectId instead of skipping it' do
      collection = instance_double(Mongo::Collection)
      cursor = instance_double(Mongo::Collection::View)
      allow(db_double).to receive(:[]).with(:people).and_return(collection)
      expect(collection).to receive(:find).with('_id' => { '$in' => ['legacy-id'] }).and_return(cursor)
      allow(cursor).to receive(:batch_size).and_return([{ '_id' => 'legacy-id' }])

      found = []
      verifier.send(:each_prehash_record, 'people', { 'legacy-id' => ['digest'] }) { |doc, _stored| found << doc['_id'] }
      expect(found).to eq(['legacy-id'])
    end
  end

  describe '#check_name_dob_prehash' do
    it 'fails when an external run has no remaining canonical digests' do
      verifier = described_class.new(prehash_map: {}, hmac_key: 'key', run_id: 'expired-run')
      expect(verifier.send(:check_name_dob_prehash)[:issues]).to include('No canonical digests stored')
    end

    context 'when prehash_map or hmac_key is missing' do
      it 'marks itself skipped rather than passing when both are nil' do
        result = verifier.send(:check_name_dob_prehash)
        expect(result[:skipped]).to be true
        expect(result[:issues]).to eq('None')
        expect(result[:samples]).to include('SKIPPED')
        expect(result[:samples]).to include('Name and DOB mutation NOT verified')
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

  describe 'slot payloads with missing embedded entries' do
    it 'treats a nil profile or dependent as an empty slot' do
      expect(verifier.send(:canonical_identity_payloads, { 'legal_name' => 'X', 'profiles' => [nil] })).to eq(['x', '', '', ''])
      expect(verifier.send(:canonical_gender_payloads, { 'gender' => 'male', 'census_dependents' => [nil] })).to eq(['male', ''])
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

    it 'no longer includes dba, which is now replaced and so can be policed' do
      expect(skip_fields).not_to include('dba')
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

    it 'yields dba so an unanonymized numeric one is caught' do
      doc = { 'dba' => '125000024', 'legal_name' => 'Acme Corp' }
      expect(verifier.send(:doc_strings, doc).to_a).to contain_exactly('125000024', 'Acme Corp')
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
