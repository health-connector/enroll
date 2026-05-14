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
      it 'returns a result indicating not provided' do
        result = verifier.send(:check_name_dob_prehash)
        expect(result[:passed]).to be true
        expect(result[:samples]).to eq('not provided')
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
end
