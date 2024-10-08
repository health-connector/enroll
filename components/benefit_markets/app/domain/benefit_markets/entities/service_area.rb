# frozen_string_literal: true

module BenefitMarkets
  module Entities
    class ServiceArea < Dry::Struct
      transform_keys(&:to_sym)

      attribute :_id,                                 Types::Bson
      attribute :active_year,                         Types::Strict::Integer
      attribute :issuer_provided_title,               Types::Strict::String
      attribute :issuer_provided_code,                Types::Strict::String
      attribute :issuer_profile_id,                   Types::Bson
      attribute :issuer_hios_id,                      Types::String.optional
      attribute :county_zip_ids,                      Types::Array.optional
      attribute :covered_states,                      Types::Array.optional

    end
  end
end