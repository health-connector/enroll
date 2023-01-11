# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitSponsors
  module Operations
    module BenefitSponsorship
      # This operation is to find Estimatd Employee Costs
      class EstimatedEmployeeCosts
        include Dry::Monads[:result, :do]

        def call(params)
          values = yield validate(params)
          result = yield estimated_employee_costs(values)

          Success(result)
        end

        private

        def validate(params)
          return Failure('Invalid params. Missing benefit_application') unless params[:benefit_application]
          return Failure('Invalid params. Missing benefit_package') unless params[:benefit_package]

          Success(params)
        end

        def estimated_employee_costs(values)
          sponsored_benefit = if values[:package_kind] == "dental"
                                values[:benefit_package].sponsored_benefits.where(_type: "BenefitSponsors::SponsoredBenefits::DentalSponsoredBenefit").first
                              else
                                values[:benefit_package].sponsored_benefits.where(_type: "BenefitSponsors::SponsoredBenefits::HealthSponsoredBenefit").first
                              end
          product_package = sponsored_benefit.product_package

          estimator = ::BenefitSponsors::Services::SponsoredBenefitCostEstimationService.new
          @employee_costs = estimator.calculate_employee_estimates_for_all_products_in_package(values[:benefit_application], sponsored_benefit, sponsored_benefit.reference_product, product_package)
          @employer_estimated_costs = estimator.calculate_estimates_for_package_edit(values[:benefit_application], sponsored_benefit, sponsored_benefit.reference_product, product_package)
          result = { employee_costs: @employee_costs, employer_estimated_costs: @employer_estimated_costs, reference_product: sponsored_benefit.reference_product }
          Success(result)
        end
      end
    end
  end
end
