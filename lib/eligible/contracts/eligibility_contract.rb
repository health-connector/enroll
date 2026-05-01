# frozen_string_literal: true

module Eligible
  module Contracts
    # Contract for Eligibile::Eligibility
    class EligibilityContract < Contract
      params do
        optional(:_id).filled(:string)
        required(:key).filled(:symbol)
        required(:title).filled(:string)
        optional(:description).maybe(:string)
        required(:current_state).filled(:symbol)
        required(:evidences).filled(:array)
        required(:grants).filled(:array)
        required(:state_histories).filled(:array)
        optional(:timestamps).maybe(
          Eligible::Contracts::TimeStampContract.params
        )
      end

      rule(:key) do
        # Convert symbol to string for entity
        values[:key] = value.to_s if value.is_a?(Symbol)
      end

      rule(:evidences).each do
        next unless key? && value
        next if value.is_a?(Eligible::Entities::Evidence)

        # Simplified: just use Evidence class directly instead of resource registry
        resource_name = Eligible::Entities::Evidence

        result = Eligible::Contracts::EvidenceContract.new.call(value)
        if result&.failure?
          key.failure(text: "invalid evidence", error: result.errors.to_h)
        else
          values[:evidences][path.to_a[-1]] = resource_name.new(result.to_h)
        end
      end

      rule(:grants).each do
        next unless key? && value
        next if value.is_a?(Eligible::Entities::Grant)

        # Simplified: just use Grant class directly instead of resource registry
        resource_name = Eligible::Entities::Grant

        result = Eligible::Contracts::GrantContract.new.call(value)
        if result&.failure?
          key.failure(text: "invalid grant", error: result.errors.to_h)
        else
          values[:grants][path.to_a[-1]] = resource_name.new(result.to_h)
        end
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
