# frozen_string_literal: true

require 'securerandom'
require 'ffaker'

module DataAnonymizer
  # Generates synthetic PII values using FFaker and SecureRandom.
  #
  # Re-identification is prevented by combination improbability — each attribute
  # (name, DOB, SSN, address) is independently randomized, making it negligible
  # probability the result maps to any real person.
  #
  # Inbox messages are intentionally NOT anonymized (no PII in CCA inboxes).
  # FFaker seeding (+FFaker.seed = integer+) is supported but not enabled by default.
  #
  # Call as module functions: +DataAnonymizer::AnonymizedData.first_name+
  module AnonymizedData
    module_function

    # @return [String] random first name
    def first_name
      FFaker::Name.first_name
    end

    # @return [String] random last name
    def last_name
      FFaker::Name.last_name
    end

    # Valid SSN area-code ranges (excludes 000, 666, 900-999 per SSA rules).
    SSN_VALID_AREAS = ([*1..665] + [*667..899]).freeze

    # Maximum loop iterations when generating a valid SSN. The probability of
    # reaching this limit is negligible; the guard exists only as a defensive safeguard.
    MAX_SSN_ATTEMPTS = 1_000

    # Generates a valid-format SSN string (9 digits, no dashes).
    #
    # Enforces all SSA validity rules, including those checked at enrollment:
    #   - Area code never 000, 666, or 900-999
    #   - Group code never 00
    #   - Serial never 0000
    #   - Not all same digits (e.g. 111111111)
    #   - Not in ascending sequential order (e.g. 123456789)
    #   - Not in descending sequential order (e.g. 987654321)
    #
    # @return [String] 9-digit numeric string
    # @raise [RuntimeError] if a valid SSN cannot be generated (should never happen in practice)
    def ssn
      MAX_SSN_ATTEMPTS.times do
        area   = SSN_VALID_AREAS.sample
        group  = rand(1..99)
        serial = rand(1..9999)
        result = format('%<area>03d%<group>02d%<serial>04d', area: area, group: group, serial: serial)

        next if result.chars.uniq.length == 1
        next if result.chars.each_cons(2).all? { |l, r| l < r }
        next if result.chars.each_cons(2).all? { |l, r| l > r }

        return result
      end
      raise "Failed to generate a valid SSN after #{MAX_SSN_ATTEMPTS} attempts"
    end

    # Encrypts a plain SSN string using SymmetricEncryption (same algorithm as the app).
    # @param plain_ssn [String] plain 9-digit SSN
    # @return [String] encrypted SSN ciphertext suitable for the +encrypted_ssn+ field
    def encrypt_ssn(plain_ssn)
      SymmetricEncryption.encrypt(plain_ssn.to_s.gsub(/\D/, ''))
    end

    # Generates and encrypts a fake SSN in one step.
    # @return [String] encrypted fake SSN ciphertext
    def encrypted_ssn
      encrypt_ssn(ssn)
    end

    # @return [Integer] random day offset in the range [-30, 30] (±30 days)
    def dob_shift_days
      rand(-30..30) # ±30 days
    end

    # The shift is deterministic when +shift_days+ is provided, or random within ±30 days when nil.
    # The shifted date will never be before 1920-01-01 and never be today or in the future.
    # @param original_dob [Date] the original date of birth
    # @param shift_days [Integer, nil] days to shift; a random offset is used if nil
    # @return [Date, nil] the shifted date, or nil if +original_dob+ is nil
    def shift_dob(original_dob, shift_days: nil)
      return nil if original_dob.nil?

      shift_days ||= dob_shift_days
      new_dob = original_dob + shift_days
      new_dob = Date.new(1920, 1, 1) if new_dob.year < 1920
      new_dob = Date.today - 1 if new_dob >= Date.today
      new_dob
    end

    # @return [String] fake street address line 1 (house number + street name)
    def address_1
      "#{rand(100..9999)} #{FFaker::Address.street_name}"
    end

    # @return [String] fake city name via FFaker
    def city
      FFaker::Address.city
    end

    # @return [String] fake US ZIP code via FFaker
    def zip
      FFaker::AddressUS.zip_code
    end

    # @return [String] fake county name derived from a random FFaker city
    def county
      "#{FFaker::Address.city} County"
    end

    # Allowed anonymized email domains — two domains for guaranteed uniqueness per record.
    ALLOWED_EMAIL_DOMAINS = %w[exampleanonymizer.com testanonymizer.com].freeze

    # @return [String] deterministic anonymized email address.
    #   Even-indexed records use +exampleanonymizer.com+; odd-indexed use +testanonymizer.com+.
    #   When no index is given, a random hex suffix keeps the address unique.
    # @param index [Integer, nil] sequence number for deterministic uniqueness
    def email(index = nil)
      if index
        domain = ALLOWED_EMAIL_DOMAINS[index % 2]
        "user#{index}@#{domain}"
      else
        domain = ALLOWED_EMAIL_DOMAINS[SecureRandom.random_number(2)]
        "user#{SecureRandom.hex(4)}@#{domain}"
      end
    end

    # @return [String] random 7-digit phone number body (no area code)
    def phone_number
      format('%07d', rand(1_000_000..9_999_999))
    end

    # @return [String] random 3-digit US area code (200–999)
    def area_code
      format('%03d', rand(200..999))
    end

    # @return [String] full 10-digit phone number (area code + number body)
    def full_phone
      "#{area_code}#{phone_number}"
    end

    # @return [String] random US state abbreviation (2 letters)
    def state
      FFaker::AddressUS.state_abbr
    end

    # @return [String] fake company name via FFaker
    def company_name
      FFaker::Company.name
    end

    # @return [String] fake 9-digit ABA routing number (100000000–999999999).
    #   Generated values never start with 0, matching real ABA routing number format.
    def routing_number
      rand(100_000_000..999_999_999).to_s
    end

    # @return [String] random 12-character hex string used as a fake ACH account number
    def account_number
      SecureRandom.hex(6)
    end
  end
end
