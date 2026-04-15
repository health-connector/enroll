# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Eligible
  module Operations
    # Create Eligibility
    class AddEligibility
      send(:include, Dry::Monads[:result, :do])

      # @params [Hash] opts Options to create eligibility
      # @option opts [String] :subject required
      # @option opts [Hash] :eligibility required
      # @return [Dry::Monad] result
      def call(params)
        values = yield validate_input_params(params)
        eligibility = yield create_eligibility(values)

        Success(eligibility)
      end

      private

      def validate_input_params(params)
        return Failure('subject is required') unless params[:subject]
        return Failure('eligibility is required') unless params[:eligibility]

        params[:subject] = params[:subject].classify.constantize
        Success(params)
      end

      def create_eligibility(values)
        Eligible::Operations::CreateEligibilityType.new.call(
          values.slice(:subject, :eligibility)
        )
      end
    end
  end
end
