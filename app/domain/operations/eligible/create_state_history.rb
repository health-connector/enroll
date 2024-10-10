# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Operations
  module Eligible
    # Operation to create a state history for eligibility items.
    class CreateStateHistory
      include Dry::Monads[:do, :result]

      # Creates a state history entry for a given eligibility and evidence item.
      #
      # @param [Hash] opts Options to create state history.
      # @option opts [GlobalID] :subject (required) The subject for which state history is being created.
      # @option opts [AcaEntities::Elgibilities::EligibilityItem] :eligibility_item (required) The associated eligibility item.
      # @option opts [AcaEntities::Elgibilities::EvidenceItem] :evidence_item (required) The associated evidence item.
      # @option opts [Date] :effective_date (required) The date the state history takes effect.
      #
      # @return [Dry::Monads::Result] Success with created eligibility state history or Failure with validation errors.
      def call(params)
        values = yield validate(params)
        eligibility = yield create(values)

        Success(eligibility)
      end

      private

      def validate(params)
        contract_result = AcaEntities::Eligible::StateHistoryContract.new.call(params)
        contract_result.success? ? Success(contract_result.to_h) : contract_result
      end

      def create(values)
        Success(AcaEntities::Eligible::StateHistory.new(values))
      end
    end
  end
end
