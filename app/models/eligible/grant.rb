# frozen_string_literal: true

module Eligible
  # The Grant class represents a specific grant associated with an eligibility record.
  #
  # Each grant has a unique key, title, description, and an embedded value.
  # Grants are used to determine the conditions and entitlements associated with
  # eligibility.
  #
  # @example
  #   eligibility.grants.build(title: "Income Grant", key: :income_grant)
  class Grant
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :eligibility, class_name: "::Eligible::Eligibility"

    field :key, type: Symbol
    field :title, type: String
    field :description, type: String

    embeds_one :value, class_name: "::Eligible::Value", cascade_callbacks: true

    validates_presence_of :title, :key

    scope :by_key, ->(key) { where(key: key.to_sym) }
  end
end
