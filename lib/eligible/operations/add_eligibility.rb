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

      ALLOWED_SUBJECT_TYPES = %w[
        BenefitSponsors::Organizations::AcaShopCcaEmployerProfile
        BenefitSponsors::Organizations::AcaShopDcEmployerProfile
        BenefitMarkets::Products::HealthProducts::HealthProduct
        BenefitMarkets::Products::DentalProducts::DentalProduct
      ].freeze

      def validate_input_params(params)
        return Failure('subject is required') unless params[:subject]
        return Failure('eligibility is required') unless params[:eligibility]

        subject_class_name = params[:subject].classify
        return Failure("Invalid subject type: #{subject_class_name}") unless ALLOWED_SUBJECT_TYPES.include?(subject_class_name)

        params[:subject] = subject_class_name.constantize
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
