module SponsoredBenefits
  module Organizations
    class PlanDesignProposals::PlanComparisonsController < ApplicationController
      include ApplicationHelper

      def new
        @sort_by = params[:sort_by].rstrip
        # Sorting by the same parameter alternates between ascending and descending
        @order = @sort_by == session[:sort_by_copay] ? -1 : 1
        session[:sort_by_copay] = @order == 1 ? @sort_by : ''
        if @sort_by && !@sort_by.empty?
          @sort_by = @sort_by.strip
          sort_array = qhps.map do |qhp|
            [qhp, get_visit_cost(qhp,@sort_by)]
          end
          sort_array.sort!{|a,b| a[1] * @order <=> b[1] * @order}
          @qhps = sort_array.map{|item| item[0]}
        end
        @employer_costs = calculate_employer_costs
      end

      def export
        render pdf: 'plan_comparison_export',
               template: 'sponsored_benefits/organizations/plan_design_proposals/plan_comparisons/_export.html.erb',
               disposition: 'attachment',
               locals: { qhps: qhps, employer_costs: calculate_employer_costs, visit_types: visit_types }
      end

      def csv
        # Use employer costs from params if provided (from the comparison table)
        # Otherwise recalculate them
        employer_costs_data = if params[:employer_costs].present?
                                parse_employer_costs_from_params
                              else
                                calculate_employer_costs
                              end

        @qhps = qhps.each do |qhp|
          plan_id = qhp.plan.id
          qhp[:total_employee_cost] = employer_costs_data[plan_id] || 0.00
        end
        respond_to do |format|
          format.csv do
            send_data(::Products::Qhp.csv_for(qhps, visit_types), type: csv_content_type, filename: "comparsion_plans.csv")
          end
        end
      end

      private

      helper_method :plan_design_form, :plan_design_organization, :plan_design_proposal, :visit_types, :qhps, :employer_costs, :coverage_kind

      def coverage_kind
        @coverage_kind ||= params[:kind]&.capitalize || benefit_group_params[:kind]&.capitalize || 'Health'
      end

      def parse_employer_costs_from_params
        # Parse employer costs from params (format: plan_id:cost,plan_id:cost)
        params[:employer_costs].split(',').each_with_object({}) do |pair, hash|
          plan_id, cost = pair.split(':')
          hash[BSON::ObjectId.from_string(plan_id)] = cost.to_f
        end
      rescue StandardError => e
        Rails.logger.error("Error parsing employer costs from params: #{e.message}")
        {}
      end

      def employer_costs
        @employer_costs ||= calculate_employer_costs
      end

      def calculate_employer_costs
        sponsorship = plan_design_proposal.profile&.benefit_sponsorships&.first
        return {} unless sponsorship

        benefit_application = sponsorship.benefit_applications&.first
        return {} unless benefit_application

        qhps.each_with_object({}) do |qhp, costs|
          next unless qhp.plan.present?

          # Fetch a fresh benefit group for EACH plan to avoid state pollution
          benefit_group = build_fresh_benefit_group_for_calculation(benefit_application)
          return costs if benefit_group.nil?

          costs[qhp.plan.id] = cost_for_plan(benefit_group, qhp.plan)
        rescue StandardError => e
          Rails.logger.error "Error calculating cost for plan #{qhp.plan&.id}: #{e.message}"
          costs[qhp.plan.id] = 0.00 if qhp.plan.present?
        end
      end

      def build_fresh_benefit_group_for_calculation(benefit_application)
        return nil unless benefit_application

        active_benefit_group = benefit_application.benefit_groups&.first
        return nil unless active_benefit_group

        if benefit_group_params.present?
          if coverage_kind == 'Dental'
            # For dental, build from association but set dental-specific attributes
            active_benefit_group = benefit_application.benefit_groups.build(benefit_group_params)
            active_benefit_group.plan_option_kind = params[:elected_plan_kind] if params[:elected_plan_kind].present?
            active_benefit_group.dental_reference_plan_id = params[:dental_reference_plan_id] if params[:dental_reference_plan_id].present?
            populate_relationship_benefits_from_dental_attrs(active_benefit_group)
          else
            # For health, use original logic: build from association
            active_benefit_group = benefit_application.benefit_groups.build(benefit_group_params)
            active_benefit_group.title ||= "Plan Comparison Benefit Group #{Time.now.to_i}"
            active_benefit_group.plan_option_kind = params[:elected_plan_kind] if params[:elected_plan_kind].present?
            active_benefit_group.reference_plan_id = params[:reference_plan_id] if params[:reference_plan_id].present?
            active_benefit_group.build_estimated_composite_rates if active_benefit_group.sole_source?
            active_benefit_group.set_bounding_cost_plans
          end
        end

        active_benefit_group
      end

      def cost_for_plan(benefit_group, plan)
        if plan.dental?
          calculate_dental_cost_for_all_employees(benefit_group, plan)
        else
          calculate_health_cost(benefit_group, plan)
        end
      end

      def calculate_health_cost(benefit_group, plan)
        temp_benefit_group = build_temp_benefit_group_for_plan(benefit_group, plan)
        service = SponsoredBenefits::Services::PlanCostService.new(benefit_group: temp_benefit_group)
        service.monthly_employer_contribution_amount || 0.00
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def fetch_benefit_group_for_calculation
        sponsorship = plan_design_proposal.profile&.benefit_sponsorships&.first
        return nil unless sponsorship

        benefit_application = sponsorship.benefit_applications&.first
        return nil unless benefit_application

        active_benefit_group = benefit_application.benefit_groups&.first

        if benefit_group_params.present?
          if coverage_kind == 'Dental'
            # For dental, build from association but set dental-specific attributes
            active_benefit_group = benefit_application.benefit_groups.build(benefit_group_params)
            active_benefit_group.plan_option_kind = params[:elected_plan_kind] if params[:elected_plan_kind].present?
            active_benefit_group.dental_reference_plan_id = params[:dental_reference_plan_id] if params[:dental_reference_plan_id].present?
            populate_relationship_benefits_from_dental_attrs(active_benefit_group)
          else
            # For health, use original logic: build from association
            active_benefit_group = benefit_application.benefit_groups.build(benefit_group_params)
            active_benefit_group.title ||= "Plan Comparison Benefit Group #{Time.now.to_i}"
            active_benefit_group.plan_option_kind = params[:elected_plan_kind] if params[:elected_plan_kind].present?
            active_benefit_group.reference_plan_id = params[:reference_plan_id] if params[:reference_plan_id].present?
            active_benefit_group.build_estimated_composite_rates if active_benefit_group.sole_source?
            active_benefit_group.set_bounding_cost_plans
          end
        end

        active_benefit_group
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def setup_dental_benefit_group(benefit_group)
        benefit_group.assign_attributes(
          plan_option_kind: params[:elected_plan_kind],
          reference_plan_id: params[:reference_plan_id],
          dental_reference_plan_id: params[:dental_reference_plan_id]
        )

        populate_relationship_benefits_from_dental_attrs(benefit_group)
      end

      def populate_relationship_benefits_from_dental_attrs(benefit_group)
        dental_attrs = benefit_group_params&.dig('dental_relationship_benefits_attributes')
        return unless coverage_kind == 'Dental' && dental_attrs.present?

        benefit_group.relationship_benefits.clear
        dental_attrs.each_value do |attrs|
          next unless attrs.present?

          benefit_group.relationship_benefits.build(
            relationship: attrs['relationship'],
            premium_pct: attrs['premium_pct'],
            offered: attrs['offered'].to_s == 'true' || !attrs.key?('offered')
          )
        end
      end

      def build_temp_benefit_group_for_plan(benefit_group, plan)
        temp_bg = benefit_group.class.new(
          reference_plan_id: plan.dental? ? benefit_group.reference_plan_id : plan.id,
          dental_reference_plan_id: plan.dental? ? plan.id : nil,
          plan_option_kind: benefit_group.plan_option_kind,
          elected_plan_ids: [plan.id],
          title: "Temp Cost Calc #{Time.now.to_i}_#{plan.id}"
        )
        temp_bg.benefit_application = benefit_group.benefit_application

        copy_relationship_benefits(benefit_group, temp_bg)

        if benefit_group.sole_source?
          copy_composite_tiers(benefit_group, temp_bg)
        end

        temp_bg.set_bounding_cost_plans unless plan.dental?
        temp_bg
      end

      def copy_relationship_benefits(source, target)
        source.relationship_benefits.each do |rb|
          target.relationship_benefits.build(
            relationship: rb.relationship,
            premium_pct: rb.premium_pct,
            offered: rb.offered
          )
        end
      end

      def copy_composite_tiers(source, target)
        source.composite_tier_contributions.each do |ctc|
          target.composite_tier_contributions.build(
            composite_rating_tier: ctc.composite_rating_tier,
            employer_contribution_percent: ctc.employer_contribution_percent,
            offered: ctc.offered
          )
        end
        target.estimate_composite_rates
      end

      def calculate_dental_cost_for_all_employees(benefit_group, plan)
        # Use PlanCostService for dental plans (same as health plans)
        # This is the "right way" approach - using the centralized service ensures consistency
        # with single-plan calculations and handles complex scenarios like COBRA, composite rates, etc.
        #
        # LIMITATIONS (for future developer reference):
        # - PlanCostService was designed primarily for health plans with SIC code lookups
        # - For dental, the set_bounding_cost_plans call may fail (we skip it for dental)
        # - Results may differ from custom calculation due to how PlanCostService handles:
        #   * Composite vs. individual rating
        #   * COBRA employee status
        #   * Actual enrolled family members vs. theoretical relationships
        #   * Rating area adjustments
        # - To improve accuracy, PlanCostService would need dental-specific adjustments
        temp_benefit_group = build_temp_benefit_group_for_plan(benefit_group, plan)
        service = SponsoredBenefits::Services::PlanCostService.new(benefit_group: temp_benefit_group)
        # Must pass the plan explicitly for dental so it uses dental_reference_plan_id
        service.monthly_employer_contribution_amount(plan) || 0.00
      rescue StandardError => e
        Rails.logger.error "Error calculating dental cost for plan #{plan.id} using PlanCostService: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        0.00
      end

      def plan_design_proposal
        @plan_design_proposal ||= SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:plan_design_proposal_id])
      end

      def plan_design_organization
        @plan_design_organization ||= plan_design_proposal.plan_design_organization
      end

      def requested_plans
        @requested_plans ||= ::Plan.where(:_id => { '$in': params[:plans].to_a }).map(&:hios_id)
        @plans = @requested_plans
      end

      def qhps
        @qhps ||= ::Products::QhpCostShareVariance.find_qhp_cost_share_variances(requested_plans, plan_design_proposal.effective_date.year, coverage_kind)
      end

      def visit_types
        @visit_types ||= coverage_kind == 'Health' ? ::Products::Qhp::VISIT_TYPES : ::Products::Qhp::DENTAL_VISIT_TYPES
      end

      def csv_content_type
        case request.user_agent
        when /windows/i
          'application/vnd.ms-excel'
        else
          'text/csv'
        end
      end

      def benefit_group_params
        return {} unless params[:forms_plan_design_proposal].present?

        benefit_group_data = params[:forms_plan_design_proposal]
                             .dig(:profile, :benefit_sponsorship, :benefit_application, :benefit_group)

        return {} unless benefit_group_data.present?

        benefit_group_data.permit(
          :reference_plan_id,
          :dental_reference_plan_id,
          :plan_option_kind,
          :kind,
          relationship_benefits_attributes: [:relationship, :premium_pct, :offered],
          dental_relationship_benefits_attributes: [:relationship, :premium_pct, :offered],
          composite_tier_contributions_attributes: [:composite_rating_tier, :employer_contribution_percent, :offered]
        )
      end
    end
  end
end
