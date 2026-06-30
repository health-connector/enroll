# frozen_string_literal: true

module Eligible
  module Contracts
    # Contract for Grant
    class GrantContract < Contract
      params do
        optional(:_id).filled(:string)
        required(:key).filled(:symbol)
        required(:title).filled(:string)
        optional(:description).maybe(:string)
        required(:value).filled(:hash)
        required(:state_histories).filled(:array)
        optional(:timestamps).maybe(
          Eligible::Contracts::TimeStampContract.params
        )
      end

      rule(:key) do
        # Convert symbol to string for entity
        values[:key] = value.to_s if value.is_a?(Symbol)
      end

      rule(:value) do
        next unless key? && value
        next if value.is_a?(Eligible::Entities::Value)

        result = Eligible::Contracts::ValueContract.new.call(value)
        next unless result&.failure?

        key.failure(text: "invalid value", error: result.errors.to_h)
      end

      rule(:state_histories).each do
        next unless key? && value
        next if value.is_a?(Eligible::Entities::StateHistory)

        result = Eligible::Contracts::StateHistoryContract.new.call(value)
        next unless result&.failure?

        key.failure(text: "invalid state history", error: result.errors.to_h)
      end
    end
  end
end
