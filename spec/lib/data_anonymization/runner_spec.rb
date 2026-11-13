# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/data_anonymization/anonymized_data'
require_relative '../../../lib/data_anonymization/runner'

RSpec.describe DataAnonymizer::Runner, dbclean: :around_each do
  let(:batch_size) { 100 }

  subject(:runner) do
    described_class.new(
      batch_size: batch_size,
      dry_run: true,
      force: true
    )
  end
  # @!group Constructor / flags — constructor and flag behavior tests

  describe '#initialize' do
    it 'sets dry_run' do
      r = described_class.new(dry_run: true, force: true)
      expect(r.instance_variable_get(:@dry_run)).to be true
    end

    it 'defaults all anonymize flags to false (fields are preserved by default)' do
      r = described_class.new(force: true)
      expect(r.instance_variable_get(:@anonymize_zip)).to    be false
      expect(r.instance_variable_get(:@anonymize_county)).to be false
      expect(r.instance_variable_get(:@anonymize_dob)).to    be false
      expect(r.instance_variable_get(:@anonymize_state)).to  be false
    end

    it 'accepts all anonymize flags set to true' do
      r = described_class.new(
        force: true,
        anonymize_zip: true,
        anonymize_county: true,
        anonymize_dob: true,
        anonymize_state: true
      )
      expect(r.instance_variable_get(:@anonymize_zip)).to    be true
      expect(r.instance_variable_get(:@anonymize_county)).to be true
      expect(r.instance_variable_get(:@anonymize_dob)).to    be true
      expect(r.instance_variable_get(:@anonymize_state)).to  be true
    end
  end

  # @!group Address anonymization — address anonymization tests

  describe '#anonymize_address_hash' do
    let(:addr) do
      {
        'address_1' => '123 Real St',
        'address_2' => 'Apt 4',
        'city' => 'Realtown',
        'state' => 'MA',
        'zip' => '02101',
        'county' => 'Suffolk County'
      }
    end

    subject(:result) { runner.send(:anonymize_address_hash, addr) }

    it 'returns nil for a nil input' do
      expect(runner.send(:anonymize_address_hash, nil)).to be_nil
    end

    it 'replaces address_1' do
      expect(result['address_1']).not_to eq('123 Real St')
    end

    it 'clears address_2' do
      expect(result['address_2']).to be_nil
    end

    it 'replaces city' do
      expect(result['city']).not_to eq('Realtown')
    end

    it 'preserves state by default' do
      expect(result['state']).to eq('MA')
    end

    it 'preserves zip by default' do
      expect(result['zip']).to eq('02101')
    end

    it 'preserves county by default' do
      expect(result['county']).to eq('Suffolk County')
    end

    context 'when anonymize_state is true' do
      subject(:runner_with_state) do
        described_class.new(dry_run: true, force: true, anonymize_state: true)
      end

      it 'replaces state' do
        result = runner_with_state.send(:anonymize_address_hash, addr)
        expect(result['state']).not_to eq('MA')
        expect(result['state']).to match(/\A[A-Z]{2}\z/)
      end
    end

    context 'when anonymize_zip is true' do
      subject(:runner_with_zip) do
        described_class.new(dry_run: true, force: true, anonymize_zip: true)
      end

      it 'replaces zip' do
        result = runner_with_zip.send(:anonymize_address_hash, addr)
        expect(result['zip']).not_to eq('02101')
      end
    end

    context 'when anonymize_county is true' do
      subject(:runner_with_county) do
        described_class.new(dry_run: true, force: true, anonymize_county: true)
      end

      it 'replaces county' do
        result = runner_with_county.send(:anonymize_address_hash, addr)
        expect(result['county']).not_to eq('Suffolk County')
      end
    end
  end

  # @!group Person date anonymization — DOB shifting tests

  describe '#anonymize_person_dates' do
    let(:doc) { { 'dob' => Date.new(1980, 3, 12), 'date_of_death' => nil } }

    context 'when anonymize_dob is false (default)' do
      it 'does not touch dob' do
        result = runner.send(:anonymize_person_dates, doc, 15)
        expect(result).not_to have_key('dob')
      end
    end

    context 'when anonymize_dob is true' do
      subject(:dob_runner) do
        described_class.new(dry_run: true, force: true, anonymize_dob: true)
      end

      it 'shifts dob by shift_days' do
        result = dob_runner.send(:anonymize_person_dates, doc, 10)
        expect(result['dob']).to eq(Date.new(1980, 3, 12) + 10)
      end

      it 'does not add date_of_death when it is nil' do
        result = dob_runner.send(:anonymize_person_dates, doc, 5)
        expect(result).not_to have_key('date_of_death')
      end
    end
  end

  # @!group Phone anonymization — phone anonymization tests

  describe '#anonymize_phone_hash' do
    let(:phone) do
      {
        'area_code' => '617',
        'number' => '5551234',
        'full_phone_number' => '6175551234',
        'extension' => '99',
        'kind' => 'work'
      }
    end

    subject(:result) { runner.send(:anonymize_phone_hash, phone) }

    it 'returns nil for nil input' do
      expect(runner.send(:anonymize_phone_hash, nil)).to be_nil
    end

    it 'replaces area_code' do
      expect(result['area_code']).not_to eq('617')
    end

    it 'replaces number' do
      expect(result['number']).not_to eq('5551234')
    end

    it 'builds full_phone_number from new area_code + number' do
      expect(result['full_phone_number']).to eq("#{result['area_code']}#{result['number']}")
    end

    it 'clears extension' do
      expect(result['extension']).to be_nil
    end

    it 'preserves structural field kind' do
      expect(result['kind']).to eq('work')
    end
  end

  # @!group Email hash anonymization — email anonymization tests

  describe '#anonymize_email_hash' do
    let(:email_hash) { { 'address' => 'real@example.com', 'kind' => 'home' } }

    subject(:result) { runner.send(:anonymize_email_hash, email_hash) }

    it 'returns nil for nil input' do
      expect(runner.send(:anonymize_email_hash, nil)).to be_nil
    end

    it 'replaces address' do
      expect(result['address']).not_to eq('real@example.com')
    end

    it 'uses an allowed domain' do
      expect(result['address']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
    end

    it 'preserves kind' do
      expect(result['kind']).to eq('home')
    end
  end

  # @!group DOB shift range — shift range/allowed_shift_range tests

  describe '#allowed_shift_range' do
    let(:ref) { Date.new(2026, 5, 14) }

    it 'returns nil for non-Date input' do
      expect(runner.send(:allowed_shift_range, nil, ref)).to be_nil
    end

    it 'returns a range bounded to ±30' do
      dob = Date.new(1970, 1, 1)
      min, max = runner.send(:allowed_shift_range, dob, ref)
      expect(min).to be >= -30
      expect(max).to be <= 30
    end

    it 'returns nil when min > max (no valid range)' do
      # A newborn (today - 1) — the 18-year band pushes min > 30
      newborn = ref - 1
      # With ±30 days the band guard should tighten the range
      result = runner.send(:allowed_shift_range, newborn, ref)
      # Either nil (impossible range) or a very tight valid range
      expect(result).to(satisfy { |r| r.nil? || (r.first <= r.last) })
    end
  end

  # @!group Canonical payloads — canonical payloads (prehash) tests

  describe '#canonical_person_payload' do
    let(:doc) do
      {
        'first_name' => 'Alice',
        'last_name' => 'Smith',
        'addresses' => [{ 'address_1' => '1 Main St', 'city' => 'Boston' }],
        'phones' => [{ 'area_code' => '617', 'number' => '5550000' }]
      }
    end

    it 'returns a downcased pipe-delimited string' do
      result = runner.send(:canonical_person_payload, doc)
      expect(result).to eq('alice|smith|1 main st|boston|6175550000')
    end

    it 'is stable for the same input' do
      expect(runner.send(:canonical_person_payload, doc)).to eq(runner.send(:canonical_person_payload, doc))
    end
  end

  describe '#canonical_org_payload' do
    let(:doc) do
      {
        'legal_name' => 'Acme Corp',
        'broker_agency_profile' => {
          'ach_routing_number' => '021000021',
          'ach_account_number' => '9876543210'
        }
      }
    end

    it 'returns downcased legal name and ACH fields' do
      result = runner.send(:canonical_org_payload, doc)
      expect(result).to eq('acme corp|021000021|9876543210')
    end
  end

  # @!group apply_family_shifts — DOB shift assignment tests

  describe '#apply_family_shifts' do
    let(:id_a) { BSON::ObjectId.new }
    let(:id_b) { BSON::ObjectId.new }
    let(:id_c) { BSON::ObjectId.new }
    let(:dob_lookup) do
      {
        id_a => Date.new(1980, 1, 1),
        id_b => Date.new(1982, 6, 15),
        id_c => Date.new(1990, 3, 10)
      }
    end

    it 'assigns a shift to each person in each family' do
      shift_map = {}
      runner.send(:apply_family_shifts, shift_map, [[id_a, id_b]], dob_lookup)
      expect(shift_map).to have_key(id_a)
      expect(shift_map).to have_key(id_b)
    end

    it 'assigns the same shift to all members of one family' do
      shift_map = {}
      runner.send(:apply_family_shifts, shift_map, [[id_a, id_b]], dob_lookup)
      expect(shift_map[id_a]).to eq(shift_map[id_b])
    end

    context 'when a person belongs to two families (shared family member)' do
      # Family 1: {A, B}; Family 2: {A, C}
      # Person A should keep the shift from Family 1 (first-family-wins).
      it 'does not overwrite an already-assigned shift for the shared member' do
        shift_map = {}
        runner.send(:apply_family_shifts, shift_map, [[id_a, id_b], [id_a, id_c]], dob_lookup)

        # A's shift is locked in after Family 1; B must share that same shift.
        expect(shift_map[id_a]).to eq(shift_map[id_b])
      end

      it 'still assigns a shift to the non-shared member of the second family' do
        shift_map = {}
        runner.send(:apply_family_shifts, shift_map, [[id_a, id_b], [id_a, id_c]], dob_lookup)
        expect(shift_map).to have_key(id_c)
      end
    end

    it 'skips empty person_ids arrays without raising' do
      shift_map = {}
      expect { runner.send(:apply_family_shifts, shift_map, [[]], dob_lookup) }.not_to raise_error
      expect(shift_map).to be_empty
    end
  end

  # @!group BS profile anonymization — anonymize_bs_profile tests

  describe '#anonymize_bs_profile' do
    let(:base_profile) do
      {
        'ach_routing_number' => '021000021',
        'ach_account_number' => 'abc123def456',
        'office_locations' => []
      }
    end

    it 'replaces ach_routing_number with a 9-digit fake' do
      result = runner.send(:anonymize_bs_profile, base_profile)
      expect(result['ach_routing_number']).not_to eq('021000021')
      expect(result['ach_routing_number']).to match(/\A[1-9]\d{8}\z/)
    end

    it 'sets ach_routing_number_confirmation to the same value as ach_routing_number' do
      result = runner.send(:anonymize_bs_profile, base_profile)
      expect(result['ach_routing_number_confirmation']).to eq(result['ach_routing_number'])
    end

    it 'replaces ach_account_number with a 16-digit numeric string' do
      result = runner.send(:anonymize_bs_profile, base_profile)
      expect(result['ach_account_number']).not_to eq('abc123def456')
      expect(result['ach_account_number']).to match(/\A[1-9]\d{15}\z/)
    end

    it 'does not change ach_routing_number when absent' do
      result = runner.send(:anonymize_bs_profile, {})
      expect(result).not_to have_key('ach_routing_number')
    end

    it 'does not mutate the original profile hash' do
      original = base_profile.dup
      runner.send(:anonymize_bs_profile, base_profile)
      expect(base_profile['ach_routing_number']).to eq(original['ach_routing_number'])
    end

    context 'when employer_attestation is present' do
      let(:profile_with_attestation) do
        base_profile.merge(
          'employer_attestation' => {
            'employer_attestation_documents' => [
              { 'title' => '185956434.pdf', 'subject' => '185956434.pdf' }
            ]
          }
        )
      end

      it 'scrubs employer_attestation_documents filenames' do
        result = runner.send(:anonymize_bs_profile, profile_with_attestation)
        doc = result.dig('employer_attestation', 'employer_attestation_documents', 0)
        expect(doc['title']).to eq('document_1.pdf')
        expect(doc['subject']).to eq('document_1.pdf')
      end
    end

    context 'when employer_attestation is absent' do
      it 'does not add an employer_attestation key' do
        result = runner.send(:anonymize_bs_profile, base_profile)
        expect(result).not_to have_key('employer_attestation')
      end
    end
  end

  # @!group Employer attestation anonymization — anonymize_employer_attestation tests

  describe '#anonymize_employer_attestation' do
    let(:attestation) do
      {
        'aasm_state' => 'approved',
        'employer_attestation_documents' => [
          { 'title' => '185956434.pdf', 'subject' => '185956434.pdf', 'created_at' => '2023-01-01' },
          { 'title' => '002310942.pdf', 'subject' => '002310942.pdf', 'created_at' => '2023-02-01' }
        ]
      }
    end

    it 'replaces title of first document with document_1.pdf' do
      result = runner.send(:anonymize_employer_attestation, attestation)
      expect(result['employer_attestation_documents'][0]['title']).to eq('document_1.pdf')
    end

    it 'replaces subject of first document with document_1.pdf' do
      result = runner.send(:anonymize_employer_attestation, attestation)
      expect(result['employer_attestation_documents'][0]['subject']).to eq('document_1.pdf')
    end

    it 'increments the index for multiple documents' do
      result = runner.send(:anonymize_employer_attestation, attestation)
      expect(result['employer_attestation_documents'][1]['title']).to eq('document_2.pdf')
      expect(result['employer_attestation_documents'][1]['subject']).to eq('document_2.pdf')
    end

    it 'preserves the file extension from the original title' do
      attestation_other_ext = {
        'employer_attestation_documents' => [{ 'title' => 'scan.docx', 'subject' => 'scan.docx' }]
      }
      result = runner.send(:anonymize_employer_attestation, attestation_other_ext)
      expect(result['employer_attestation_documents'][0]['title']).to eq('document_1.docx')
    end

    it 'preserves other fields on the attestation document' do
      result = runner.send(:anonymize_employer_attestation, attestation)
      expect(result['employer_attestation_documents'][0]['created_at']).to eq('2023-01-01')
    end

    it 'preserves top-level attestation fields (e.g. aasm_state)' do
      result = runner.send(:anonymize_employer_attestation, attestation)
      expect(result['aasm_state']).to eq('approved')
    end

    it 'does not mutate the original attestation hash' do
      original_title = attestation['employer_attestation_documents'][0]['title']
      runner.send(:anonymize_employer_attestation, attestation)
      expect(attestation['employer_attestation_documents'][0]['title']).to eq(original_title)
    end

    context 'when identifier is present' do
      let(:attestation_with_identifier) do
        {
          'employer_attestation_documents' => [
            {
              'title' => 'scan.pdf',
              'subject' => 'scan.pdf',
              'identifier' => 'urn:openhbx:terms:v1:file_storage:s3:bucket:mhc-enroll-attestations-cpr#2289fb11-c44e-41d2-bae6-9d474b6458c6'
            }
          ]
        }
      end

      it 'replaces the identifier with an anonymized URN preserving the urn structure' do
        result = runner.send(:anonymize_employer_attestation, attestation_with_identifier)
        new_id = result['employer_attestation_documents'][0]['identifier']
        expect(new_id).to start_with('urn:openhbx:terms:v1:file_storage:s3:bucket:anonymized#')
      end

      it 'generates a fresh UUID so the real document cannot be retrieved from S3' do
        result = runner.send(:anonymize_employer_attestation, attestation_with_identifier)
        new_id = result['employer_attestation_documents'][0]['identifier']
        original_uuid = '2289fb11-c44e-41d2-bae6-9d474b6458c6'
        expect(new_id).not_to include(original_uuid)
        expect(new_id).not_to include('mhc-enroll-attestations-cpr')
      end
    end

    context 'when identifier is absent' do
      it 'does not add an identifier key' do
        result = runner.send(:anonymize_employer_attestation, attestation)
        expect(result['employer_attestation_documents'][0]).not_to have_key('identifier')
      end
    end

    context 'when employer_attestation_documents is absent' do
      it 'returns the attestation unchanged' do
        att = { 'aasm_state' => 'pending' }
        result = runner.send(:anonymize_employer_attestation, att)
        expect(result).to eq({ 'aasm_state' => 'pending' })
      end
    end
  end

  # @!group BS org update builder — build_bs_org_update tests

  describe '#build_bs_org_update' do
    let(:non_issuer_profile) { { '_type' => 'BenefitSponsors::Organizations::BrokerAgencyProfile' } }
    let(:issuer_profile)     { { '_type' => 'BenefitSponsors::Organizations::IssuerProfile' } }

    context 'when the org has no issuer profile (employer / broker)' do
      let(:doc) { { 'legal_name' => 'Real Employer LLC', 'profiles' => [non_issuer_profile] } }

      it 'includes legal_name in set fields (will be replaced)' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).to have_key('legal_name')
        expect(result['legal_name']).not_to eq('Real Employer LLC')
      end

      it 'includes a processed profiles array' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).to have_key('profiles')
        expect(result['profiles']).to be_an(Array)
      end
    end

    context 'when the org has an issuer profile (carrier)' do
      let(:doc) { { 'legal_name' => 'Blue Cross Blue Shield MA', 'profiles' => [issuer_profile] } }

      it 'does NOT replace legal_name (carriers must keep their real name for downstream logo resolution)' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).not_to have_key('legal_name')
      end

      it 'still includes a processed profiles array' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).to have_key('profiles')
      end
    end

    context 'when the org has no profiles' do
      let(:doc) { { 'legal_name' => 'No Profile Org' } }

      it 'replaces legal_name' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).to have_key('legal_name')
      end

      it 'does not include a profiles key' do
        result = runner.send(:build_bs_org_update, doc)
        expect(result).not_to have_key('profiles')
      end
    end
  end

  # @!group abort_if_production! — production guard tests

  describe '#abort_if_production!' do
    let(:fake_db) { instance_double(Mongo::Database, name: 'mhc_enroll_test') }

    before do
      allow(runner).to receive(:db).and_return(fake_db)
      ENV.delete('ENV_NAME')
      ENV.delete('ENROLL_REVIEW_ENVIRONMENT')
    end

    after do
      ENV.delete('ENV_NAME')
      ENV.delete('ENROLL_REVIEW_ENVIRONMENT')
    end

    context "when ENV_NAME is a lower-env value like 'pvt' (Rails.env=test)" do
      before { ENV['ENV_NAME'] = 'pvt' }

      it 'does not abort' do
        expect { runner.send(:abort_if_production!) }.not_to raise_error
      end
    end

    context "when in a lower k8s env like 'preprod' (Rails.env=production, ENROLL_REVIEW_ENVIRONMENT=true)" do
      before do
        ENV['ENV_NAME'] = 'preprod'
        ENV['ENROLL_REVIEW_ENVIRONMENT'] = 'true'
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'does not abort' do
        expect { runner.send(:abort_if_production!) }.not_to raise_error
      end
    end

    context 'when ENV_NAME is not set' do
      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context 'when ENV_NAME is blank' do
      before { ENV['ENV_NAME'] = '' }

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context "when ENV_NAME is 'prod'" do
      before { ENV['ENV_NAME'] = 'prod' }

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context 'when Rails.env=production and ENROLL_REVIEW_ENVIRONMENT is not set' do
      before do
        ENV['ENV_NAME'] = 'pvt'
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context "when Rails.env=production and ENROLL_REVIEW_ENVIRONMENT is not 'true'" do
      before do
        ENV['ENV_NAME'] = 'preprod'
        ENV['ENROLL_REVIEW_ENVIRONMENT'] = 'false'
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context 'when database name ends in _prod' do
      let(:fake_db) { instance_double(Mongo::Database, name: 'mhc_enroll_prod') }

      before { ENV['ENV_NAME'] = 'pvt' }

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context 'when database name contains production' do
      let(:fake_db) { instance_double(Mongo::Database, name: 'mhc_production_enroll') }

      before { ENV['ENV_NAME'] = 'pvt' }

      it 'aborts' do
        expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
      end
    end

    context 'when multiple signals fire' do
      let(:fake_db) { instance_double(Mongo::Database, name: 'mhc_production_enroll') }

      it 'includes all reasons in the abort message' do
        # ENV_NAME nil + db name contains "production" — both signals should fire
        err = nil
        begin
          runner.send(:abort_if_production!)
        rescue SystemExit => e
          err = e
        end
        expect(err).not_to be_nil
        expect(err.message).to include('ENV_NAME is not set')
      end
    end
  end
end
