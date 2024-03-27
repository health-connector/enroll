# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitSponsors
  module Operations
    module BenefitApplications
      # This class revise end date of a benefit application
      class Revise
        include Dry::Monads[:result, :do]

        def call(params)
          yield validate(params)
          yield reinstate(params)
          yield terminate(params)

          Success()
        end

        private

        def validate(params)
          return Failure('Missing application key(s).') unless params.key?(:benefit_application) && params.key?(:transmit_to_carrier)
          return Failure('Missing reinstate on date.') unless params.key?(:reinstate_on)
          return Failure('Missing terminate key(s).') unless params.key?(:termination_kind) && params.key?(:termination_reason) && params.key?(:term_date)

          @benefit_application = params[:benefit_application]
          @transmit_to_carrier = params[:transmit_to_carrier]
          @reinstate_on = params[:reinstate_on]
          @current_user = params[:current_user]
          @termination_kind = params[:termination_kind]
          @termination_reason = params[:termination_reason]
          @term_date = params[:term_date]


          return Failure('Not a valid Benefit Application') unless @benefit_application.is_a?(BenefitSponsors::BenefitApplications::BenefitApplication)

          Success(params)
        end

        def reinstate(_params)
          result = BenefitSponsors::Operations::BenefitApplications::Reinstate.new.call({
                                                                                          benefit_application: @benefit_application,
                                                                                          transmit_to_carrier: @transmit_to_carrier,
                                                                                          reinstate_on: @reinstate_on,
                                                                                          current_user: @current_user
                                                                                        })
          result.success? ? Success() : Failure(result.failure)
        end

        def terminate(_params)
          service = BenefitSponsors::Services::BenefitApplicationActionService.new(@benefit_application, {
                                                                                     end_on: @term_date,
                                                                                     termination_kind: @termination_kind,
                                                                                     termination_reason: @termination_reason,
                                                                                     transmit_to_carrier: @transmit_to_carrier,
                                                                                     current_user: @current_user
                                                                                   })
          result, _application, errors = service.terminate_application

          result ? Success() : Failure(errors)
        end
      end
    end
  end
end
