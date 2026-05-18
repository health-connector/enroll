# frozen_string_literal: true

module BenefitSponsors
  module Services
    # Service to calculate employer costs for plan comparisons
    # Used to estimate monthly employer contributions for selected plans
    class PlanComparisonCostCalculator
      attr_reader :benefit_application, :form_params

      def initialize(benefit_application, form_params)
        @benefit_application = benefit_application
        @form_params = form_params
      end

      # Calculate employer costs for multiple plans
      # @param qhps [Array<Products::QhpCostShareVariance>] Array of QHP cost share variances
      # @return [Hash] Hash with plan IDs as keys and calculated costs as values
      def calculate_for_plans(qhps)
        return {} unless qhps.present? && form_params.present?

        benefit_package = build_benefit_package
        sponsored_benefit = benefit_package&.sponsored_benefits&.first
        return {} unless sponsored_benefit

        calculate_costs_for_each_plan(qhps, sponsored_benefit)
      rescue StandardError => e
        log_error("Error calculating employer costs", e)
        {}
      end

      private

      def calculate_costs_for_each_plan(qhps, sponsored_benefit)
        employer_costs = {}
        product_package = sponsored_benefit.product_package

        # Pre-warm cache for dental products to avoid missing cache entries
        # Check the first product since all products in comparison are the same kind
        first_product = qhps.first&.product
        is_dental = first_product&.kind == :dental || first_product&.dental?

        ensure_product_cache_initialized(qhps.map(&:product)) if is_dental

        qhps.each do |qhp|
          product = qhp.product

          employer_costs[product.id] = calculate_cost_for_plan(
            product,
            sponsored_benefit,
            product_package
          )
        end

        Rails.logger.info("Calculated employer costs for #{employer_costs.size} plans")
        employer_costs
      end

      def build_benefit_package
        return nil unless form_params.present?

        # Replicate the exact pattern that was working in the controller
        form = BenefitSponsors::Forms::BenefitPackageForm.new(form_params)
        form.service.load_form_metadata(form)

        application = form.service.send(:find_benefit_application, form)
        model_attributes = form.service.send(:form_params_to_attributes, form)

        model_attributes.delete(:id)
        if model_attributes[:sponsored_benefits_attributes].present?
          model_attributes[:sponsored_benefits_attributes].each do |sb_attrs|
            sb_attrs.delete(:id)
          end
        end

        BenefitSponsors::BenefitPackages::BenefitPackageFactory.call(
          application,
          model_attributes
        )
      rescue StandardError => e
        log_error("Error building benefit package", e)
        nil
      end

      def calculate_cost_for_plan(product, sponsored_benefit, product_package)
        sponsored_benefit.reference_product = product

        cost_estimator = BenefitSponsors::SponsoredBenefits::CensusEmployeeCoverageCostEstimator.new(
          benefit_application.benefit_sponsorship,
          benefit_application.effective_period.min
        )

        _sponsor_contribution, _total, employer_cost = cost_estimator.calculate(
          sponsored_benefit,
          product,
          product_package,
          rebuild_sponsor_contribution: false,
          build_new_pricing_determination: true
        )

        calculated_cost = employer_cost&.round(2) || 0.00
        Rails.logger.info("Calculated cost for plan #{product.id}: #{calculated_cost}")
        calculated_cost
      rescue StandardError => e
        log_error("Error calculating cost for plan #{product.id}", e)
        0.00
      end

      # Ensure product factor cache is initialized for dental products
      # This prevents cache lookup failures when actuarial factors aren't pre-loaded
      # rubocop:disable Style/GlobalVars
      def ensure_product_cache_initialized(products)
        products.each do |product|
          cache_key = [product.issuer_profile_id, product.active_year]
          next if $pf_cache_for_group_size&.key?(cache_key) && $pf_cache_for_group_size[cache_key].present?

          load_factors_for_product(product.issuer_profile_id, product.active_year)
        end
      rescue StandardError => e
        Rails.logger.error("Error initializing product cache: #{e.message}")
      end

      def load_factors_for_product(issuer_id, year)
        $pf_cache_for_group_size ||= {}
        $pf_cache_for_sic_code ||= {}
        $pf_cache_for_participation_percent ||= {}

        cache_key = [issuer_id, year]

        # Load or create default for group size factors
        factor = ::BenefitMarkets::Products::ActuarialFactors::GroupSizeActuarialFactor
                 .where(issuer_profile_id: issuer_id, active_year: year)
                 .first
        $pf_cache_for_group_size[cache_key] = factor ? factor.cacherize! : create_default_factor_cache

        # Load or create default for SIC code factors
        factor = ::BenefitMarkets::Products::ActuarialFactors::SicActuarialFactor
                 .where(issuer_profile_id: issuer_id, active_year: year)
                 .first
        $pf_cache_for_sic_code[cache_key] = factor ? factor.cacherize! : create_default_factor_cache

        # Load or create default for participation rate factors
        factor = ::BenefitMarkets::Products::ActuarialFactors::ParticipationRateActuarialFactor
                 .where(issuer_profile_id: issuer_id, active_year: year)
                 .first
        $pf_cache_for_participation_percent[cache_key] = factor ? factor.cacherize! : create_default_factor_cache
      end
      # rubocop:enable Style/GlobalVars

      # Create a default factor cache that returns 1.0 for any lookup
      # Used when actuarial factors don't exist in the database
      def create_default_factor_cache
        Class.new do
          def self.cached_lookup(_key)
            1.0
          end
        end
      end

      def log_error(message, exception)
        Rails.logger.error("#{message}: #{exception.message}")
        Rails.logger.error(exception.backtrace.join("\n"))
      end
    end
  end
end
