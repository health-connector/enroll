# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Eligible
  module Operations
    # Create EligibilityType
    class CreateEligibilityType
      send(:include, Dry::Monads[:result, :do])

      # @params [Hash] opts Options to create eligibility type
      # @option opts [Class] :subject required
      # @option opts [Hash] :eligibility required
      # @return [Dry::Monad] result
      def call(params)
        values = yield validate_input_params(params)
        resource_name = yield find_resource_name(values)
        validated_values = yield validate(resource_name, values[:eligibility])
        state_validated_values = yield validate_state_changes(resource_name, validated_values)
        eligibility = yield create(resource_name, state_validated_values)

        Success(eligibility)
      end

      private

      def validate_input_params(params)
        return Failure('subject is required') unless params[:subject]
        return Failure('eligibility is required') unless params[:eligibility]

        Success(params)
      end

      def find_resource_name(values)
        resource_name = values[:subject]
        return Failure("unable to find #{values[:subject]}") unless resource_name

        Success(resource_name)
      end

      def validate(_resource_name, eligibility)
        result = Eligible::Contracts::EligibilityContract.new.call(eligibility)
        result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
      end

      def validate_state_changes(resource_name, values)
        return Success(values) unless values[:state_histories]

        validator = StateChangeValidator.new(values[:state_histories], resource_name)
        validator.validate

        return Failure(validator.errors) unless validator.errors.empty?

        Success(values)
      end

      def create(resource_name, values)
        Success(resource_name.new(values))
      end
    end
  end
end
