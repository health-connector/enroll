# frozen_string_literal: true

module Eligible
  module Contracts
    # Contract for Eligible::StateHistory
    class StateHistoryContract < Dry::Validation::Contract
      params do
        optional(:_id).filled(:string)
        required(:effective_on).filled(:date)
        required(:is_eligible).filled(:bool)
        required(:from_state).filled(:symbol)
        required(:to_state).filled(:symbol)
        required(:transition_at).filled(:date_time)
        optional(:event).maybe(:symbol)
        optional(:comment).maybe(:string)
        optional(:reason).maybe(:string)
        optional(:updated_by).maybe(:string)

        optional(:timestamps).filled(
          Eligible::Contracts::TimeStampContract.params
        )
      end
    end
  end
end
