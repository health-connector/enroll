module BenefitSponsors
  module BenefitPackages
    class ProductComparisonsController < BenefitSponsors::ApplicationController
      include ApplicationHelper

      def new
        # This action can be used to render a form for selecting plans to compare
        load_benefit_application
        load_comparison_data

        respond_to do |format|
          format.json { render_comparison_response }
        end
      rescue StandardError => e
        Rails.logger.error("Error in product comparison: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        respond_to do |format|
          format.json { render json: { success: false, error: e.message }, status: :internal_server_error }
        end
      end

      def export
        # TODO: Implement CSV export functionality
      end

      def csv
        # TODO: Implement CSV generation functionality
      end

      private

      helper_method :benefit_application, :visit_types, :qhps

      attr_reader :benefit_application

      def load_benefit_application
        application_id = BSON::ObjectId.from_string(params[:benefit_application_id])
        @benefit_application = BenefitSponsors::BenefitApplications::BenefitApplication.find(application_id)
      end

      def load_comparison_data
        @qhps = qhps
        @visit_types = visit_types
        @employer_costs = calculate_employer_costs
      end

      def render_comparison_response
        render json: {
          success: true,
          html: render_to_string(
            partial: 'benefit_sponsors/benefit_packages/product_comparisons/comparison_table',
            locals: {
              qhps: @qhps,
              visit_types: @visit_types,
              employer_costs: @employer_costs
            },
            formats: [:html]
          )
        }
      end

      def requested_plans
        @requested_plans ||= begin
          plan_ids = params[:plans].split(',').map { |id| BSON::ObjectId.from_string(id.strip) }
          products = ::BenefitMarkets::Products::Product.where(:_id => { '$in': plan_ids })
          products.map(&:hios_id)
        end
      end

      def qhps
        @qhps ||= begin
          return [] unless benefit_application&.start_on

          ::Products::QhpCostShareVariance.find_qhp_cost_share_variances(
            requested_plans,
            benefit_application.start_on.year,
            "Health"
          )
        end
      end

      def visit_types
        @visit_types ||= ::Products::Qhp::VISIT_TYPES
      end

      # Calculate employer costs for the selected plans based on the form parameters
      def calculate_employer_costs
        form_params = build_form_params
        return {} if form_params.blank?

        calculator = BenefitSponsors::Services::PlanComparisonCostCalculator.new(
          @benefit_application,
          form_params
        )

        calculator.calculate_for_plans(@qhps)
      end

      # Build form parameters for the cost calculator service based on the incoming request parameters
      def build_form_params
        builder = BenefitSponsors::Services::BenefitPackageFormParamsBuilder.new(params)
        builder.build
      end
    end
  end
end