# frozen_string_literal: true

module DataAnonymizer
  # Shared canonical payload helpers used by both Runner (pre-run prehash generation)
  # and Verifier (post-run HMAC comparison). Keeping them in one place ensures
  # both sides hash identical strings for a given record.
  module CanonicalPayloads
    private

    # Canonical string for a person document (name + first address + first phone).
    # @param doc [Hash] raw person Mongo document
    # @return [String] pipe-delimited, downcased canonical string
    def canonical_person_payload(doc)
      addr  = Array(doc['addresses']).first || {}
      phone = Array(doc['phones']).first    || {}
      "#{normalize(doc['first_name'])}|#{normalize(doc['last_name'])}" \
        "|#{normalize(addr['address_1'])}|#{normalize(addr['city'])}" \
        "|#{extract_phone(phone)}"
    end

    # Canonical string for a census_member document (name + address + phone).
    # @param doc [Hash] raw census_member Mongo document
    # @return [String] pipe-delimited, downcased canonical string
    def canonical_census_payload(doc)
      addr  = doc['address'] || {}
      phone = doc['phone']   || {}
      "#{normalize(doc['first_name'])}|#{normalize(doc['last_name'])}" \
        "|#{normalize(addr['address_1'])}|#{normalize(addr['city'])}" \
        "|#{extract_phone(phone)}"
    end

    # Canonical string for a legacy organization document (legal_name + broker ACH).
    # @param doc [Hash] raw organization Mongo document
    # @return [String] pipe-delimited, downcased canonical string
    def canonical_org_payload(doc)
      bap = doc['broker_agency_profile'] || {}
      rn  = bap['ach_routing_number'].to_s.gsub(/\D/, '')
      an  = bap['ach_account_number'].to_s.gsub(/\D/, '')
      "#{normalize(doc['legal_name'])}|#{rn}|#{an}"
    end

    # Canonical string for a BS organization document (legal_name + all profile ACH).
    # @param doc [Hash] raw benefit_sponsors organization Mongo document
    # @return [String] pipe-delimited, downcased canonical string
    def canonical_bs_org_payload(doc)
      profiles = Array(doc['profiles']).map do |p|
        rn = p['ach_routing_number'].to_s.gsub(/\D/, '')
        an = p['ach_account_number'].to_s.gsub(/\D/, '')
        "#{rn}:#{an}"
      end.join(',')
      "#{normalize(doc['legal_name'])}|#{profiles}"
    end

    def normalize(str)
      str&.to_s&.strip&.downcase || ''
    end

    def extract_phone(phone)
      return '' if phone.blank?

      if phone['area_code'].present? && phone['number'].present?
        "#{phone['area_code']}#{phone['number']}"
      else
        phone['full_phone_number'].to_s.gsub(/\D/, '')
      end
    end
  end
end
