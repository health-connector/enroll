# frozen_string_literal: true

module BenefitSponsors
  module Entities
    class BenefitApplicationItem < Dry::Struct
      transform_keys(&:to_sym)

      attribute :effective_period,            Types::Range
      attribute :sequence_id,                 Types::Strict::Integer
      attribute :action_type,                 Types::Symbol.optional
      attribute :action_kind,                 Types::String.optional
      attribute :action_reason,               Types::String.optional
      attribute :action_on,                   Types::Date.optional
      attribute :updated_by,                  Types::String.optional
      attribute :state,                       Types::Symbol.optional
    end
  end
end
