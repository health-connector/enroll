# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/data_anonymization/anonymized_data'

RSpec.describe DataAnonymizer::AnonymizedData, dbclean: :around_each do
  subject(:fake) { described_module }

  let(:described_module) { DataAnonymizer::AnonymizedData }
  # @!group Names — Name-related tests

  describe '.first_name' do
    it 'returns a non-empty string' do
      expect(described_module.first_name).to be_a(String).and be_present
    end
  end

  describe '.last_name' do
    it 'returns a non-empty string' do
      expect(described_module.last_name).to be_a(String).and be_present
    end
  end

  # @!group SSN — SSN generation tests

  describe '.ssn' do
    subject(:generated) { described_module.ssn }

    it 'is a 9-digit numeric string' do
      expect(generated).to match(/\A\d{9}\z/)
    end

    it 'does not start with 000' do
      100.times { expect(described_module.ssn).not_to start_with('000') }
    end

    it 'does not start with 666' do
      100.times { expect(described_module.ssn).not_to start_with('666') }
    end

    it 'does not start with 9' do
      100.times { expect(described_module.ssn[0]).not_to eq('9') }
    end

    it 'does not end with 0000' do
      100.times { expect(described_module.ssn).not_to end_with('0000') }
    end

    it 'does not consist of all the same digit' do
      100.times do
        result = described_module.ssn
        expect(result.chars.uniq.length).to be > 1
      end
    end

    it 'is not in strict ascending sequential order' do
      100.times do
        result = described_module.ssn
        ascending = result.chars.each_cons(2).all? { |l, r| l < r }
        expect(ascending).to be false
      end
    end

    it 'is not in strict descending sequential order' do
      100.times do
        result = described_module.ssn
        descending = result.chars.each_cons(2).all? { |l, r| l > r }
        expect(descending).to be false
      end
    end

    it 'has a group code that is never 00' do
      100.times do
        result = described_module.ssn
        group = result[3..4]
        expect(group).not_to eq('00')
      end
    end

    it 'has a serial that is never 0000' do
      100.times do
        result = described_module.ssn
        serial = result[5..8]
        expect(serial).not_to eq('0000')
      end
    end
  end

  # @!group DOB Shift — DOB shifting tests

  describe '.dob_shift_days' do
    it 'returns an integer within ±30' do
      100.times do
        shift = described_module.dob_shift_days
        expect(shift).to be_a(Integer).and be_between(-30, 30)
      end
    end
  end

  describe '.shift_dob' do
    let(:base_dob) { Date.new(1985, 6, 15) }

    it 'returns nil when original_dob is nil' do
      expect(described_module.shift_dob(nil)).to be_nil
    end

    it 'shifts by the given number of days' do
      expect(described_module.shift_dob(base_dob, shift_days: 10)).to eq(base_dob + 10)
    end

    it 'clamps to 1920-01-01 minimum' do
      early = Date.new(1920, 1, 1)
      result = described_module.shift_dob(early, shift_days: -30)
      expect(result).to eq(Date.new(1920, 1, 1))
    end

    it 'never produces a date on or after today' do
      recent = Date.today - 5
      result = described_module.shift_dob(recent, shift_days: 30)
      expect(result).to be < Date.today
    end

    it 'uses a random shift when shift_days is not given' do
      result = described_module.shift_dob(base_dob)
      expect(result).to be_a(Date)
    end
  end

  # @!group Address — Address field tests

  describe '.address_1' do
    it 'is a non-empty string containing a street name' do
      expect(described_module.address_1).to be_a(String).and be_present
    end
  end

  describe '.city' do
    it 'returns a non-empty string' do
      expect(described_module.city).to be_a(String).and be_present
    end
  end

  describe '.zip' do
    it 'returns a non-empty string' do
      expect(described_module.zip).to be_a(String).and be_present
    end
  end

  describe '.county' do
    it 'contains the word County' do
      expect(described_module.county).to include('County')
    end
  end

  describe '.state' do
    it 'returns a 2-letter abbreviation' do
      expect(described_module.state).to match(/\A[A-Z]{2}\z/)
    end
  end

  # @!group Email — Email generation tests

  describe '.email' do
    context 'when an index is given' do
      it 'uses exampleanonymizer.com for even indexes' do
        expect(described_module.email(0)).to end_with('@exampleanonymizer.com')
        expect(described_module.email(2)).to end_with('@exampleanonymizer.com')
      end

      it 'uses testanonymizer.com for odd indexes' do
        expect(described_module.email(1)).to end_with('@testanonymizer.com')
        expect(described_module.email(3)).to end_with('@testanonymizer.com')
      end

      it 'embeds the index in the local part' do
        expect(described_module.email(42)).to start_with('user42@')
      end

      it 'is deterministic for the same index' do
        expect(described_module.email(7)).to eq(described_module.email(7))
      end
    end

    context 'when no index is given' do
      it 'uses one of the two allowed domains' do
        100.times do
          addr = described_module.email
          expect(addr).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
        end
      end

      it 'produces unique values across calls' do
        emails = Array.new(10) { described_module.email }
        expect(emails.uniq.length).to eq(10)
      end
    end
  end

  # @!group Phone — Phone generation tests

  describe '.phone_number' do
    it 'is a 7-digit string' do
      expect(described_module.phone_number).to match(/\A\d{7}\z/)
    end
  end

  describe '.area_code' do
    it 'is a 3-digit string in the range 200-999' do
      code = described_module.area_code.to_i
      expect(code).to be_between(200, 999)
    end
  end

  # @!group ACH — ACH (routing/account) tests

  describe '.routing_number' do
    it 'is a 9-digit string not starting with 0' do
      rn = described_module.routing_number
      expect(rn).to match(/\A[1-9]\d{8}\z/)
    end
  end

  describe '.account_number' do
    it 'is a 12-character hex string' do
      expect(described_module.account_number).to match(/\A[0-9a-f]{12}\z/)
    end
  end
end
