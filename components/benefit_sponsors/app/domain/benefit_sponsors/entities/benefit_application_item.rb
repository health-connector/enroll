# frozen_string_literal: true

module BenefitSponsors
  module Entities
    class BenefitApplicationItem < Dry::Struct
      transform_keys(&:to_sym)

      attribute :effective_period,            Types::Range
      attribute :sequence_id,                 Types::Strict::Integer
      attribute :item_type,                   Types::Symbol.optional
      attribute :item_type_reason,            Types::String.optional
      attribute :updated_by,                  Types::String.optional
      attribute :state,                       Types::Symbol.optional
    end
  end
end
