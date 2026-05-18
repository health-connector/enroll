# frozen_string_literal: true

require 'csv'

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
        load_benefit_application
        load_comparison_data

        # Use passed employer costs if available, otherwise calculate
        @employer_costs = parse_employer_costs_param if params[:employer_costs].present?

        render pdf: 'product_comparison_export',
               template: 'benefit_sponsors/benefit_packages/product_comparisons/export',
               disposition: 'attachment',
               locals: {
                 qhps: @qhps,
                 visit_types: @visit_types,
                 employer_costs: @employer_costs,
                 benefit_application: @benefit_application,
                 benefit_type: benefit_type
               }
      end

      def csv
        load_benefit_application
        load_comparison_data

        # Use passed employer costs if available
        employer_costs = params[:employer_costs].present? ? parse_employer_costs_param : @employer_costs

        # Add employer costs to each QHP object for CSV generation
        @qhps.each do |qhp|
          qhp[:total_employee_cost] = employer_costs[qhp.product.id] || 0.00
        end

        send_data(
          ::Products::Qhp.csv_for(@qhps, @visit_types),
          type: csv_content_type,
          filename: "plan_comparison_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
        )
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
              employer_costs: @employer_costs,
              benefit_type: benefit_type
            },
            formats: [:html]
          ),
          employer_costs: @employer_costs
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
        @qhps ||= if benefit_application&.start_on
                    benefit_kind = benefit_type.capitalize # 'Health' or 'Dental'
                    ::Products::QhpCostShareVariance.find_qhp_cost_share_variances(
                      requested_plans,
                      benefit_application.start_on.year,
                      benefit_kind
                    )
                  else
                    []
                  end
      end

      def benefit_type
        @benefit_type ||= (params[:benefit_type] || 'health').downcase
      end

      def visit_types
        @visit_types ||= if benefit_type == 'dental'
                           ::Products::Qhp::DENTAL_VISIT_TYPES
                         else
                           ::Products::Qhp::VISIT_TYPES
                         end
      end

      def csv_content_type
        case request.user_agent
        when /windows/i
          'application/vnd.ms-excel'
        else
          'text/csv'
        end
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

      # Parse employer costs from URL parameter (passed from modal)
      def parse_employer_costs_param
        return {} unless params[:employer_costs].is_a?(String)

        # Parse JSON string of employer costs
        parsed_costs = JSON.parse(params[:employer_costs])

        # Convert string keys back to BSON::ObjectId and ensure values are floats
        parsed_costs.transform_keys { |key| BSON::ObjectId.from_string(key) }
                    .transform_values(&:to_f)
      rescue JSON::ParserError, BSON::ObjectId::Invalid => e
        Rails.logger.error("Error parsing employer costs: #{e.message}")
        {}
      end
    end
  end
end