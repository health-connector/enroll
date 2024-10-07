# frozen_string_literal: true

module Eligible
  # The Value class represents a value associated with eligibility grants or evidences.
  #
  # Each value contains a key, title, description, and item. Values help define the specific
  # attributes or conditions associated with an eligibility object.
  #
  # @example
  #   grant.value = Eligible::Value.new(
  #     title: "Income Threshold",
  #     key: :income_threshold,
  #     item: "50000"
  #   )
  class Value
    include Mongoid::Document
    include Mongoid::Timestamps

    field :title, type: String
    field :description, type: String
    field :key, type: Symbol
    field :item, type: String

    validates_presence_of :title, :key

    def run
      true
    end
  end
end
