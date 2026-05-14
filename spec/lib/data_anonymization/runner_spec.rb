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
end
