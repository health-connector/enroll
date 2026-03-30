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

      helper_method :plan_design_form, :plan_design_organization, :plan_design_proposal, :visit_types, :qhps, :employer_costs

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
        active_benefit_group = fetch_benefit_group_for_calculation
        return {} unless active_benefit_group

        qhps.each_with_object({}) do |qhp, costs|
          next unless qhp.plan.present?

          temp_benefit_group = build_temp_benefit_group_for_plan(active_benefit_group, qhp.plan)
          service = SponsoredBenefits::Services::PlanCostService.new(benefit_group: temp_benefit_group)
          costs[qhp.plan.id] = service.monthly_employer_contribution_amount || 0.00
        rescue StandardError => e
          Rails.logger.error "Error calculating employer cost for plan #{qhp.plan&.id}: #{e.message}"
          costs[qhp.plan.id] = 0.00 if qhp.plan.present?
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def fetch_benefit_group_for_calculation
        sponsorship = plan_design_proposal.profile&.benefit_sponsorships&.first
        return nil unless sponsorship

        benefit_application = sponsorship.benefit_applications&.first
        return nil unless benefit_application

        active_benefit_group = benefit_application.benefit_groups&.first

        # Build temporary benefit group from params if none exists
        if active_benefit_group.nil? && benefit_group_params.present?
          active_benefit_group = benefit_application.benefit_groups.build(benefit_group_params)
          active_benefit_group.plan_option_kind = params[:elected_plan_kind] if params[:elected_plan_kind].present?
          active_benefit_group.reference_plan_id = params[:reference_plan_id] if params[:reference_plan_id].present?

          active_benefit_group.build_estimated_composite_rates if active_benefit_group.sole_source?
          active_benefit_group.set_bounding_cost_plans
        end

        active_benefit_group
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def build_temp_benefit_group_for_plan(active_benefit_group, plan)
        temp_bg = active_benefit_group.class.new(
          reference_plan_id: plan.id,
          plan_option_kind: active_benefit_group.plan_option_kind
        )
        temp_bg.benefit_application = active_benefit_group.benefit_application

        # Copy relationship benefits
        active_benefit_group.relationship_benefits.each do |rb|
          temp_bg.relationship_benefits.build(
            relationship: rb.relationship,
            premium_pct: rb.premium_pct,
            offered: rb.offered
          )
        end

        # Copy composite tier contributions for sole_source plans
        if active_benefit_group.sole_source?
          active_benefit_group.composite_tier_contributions.each do |ctc|
            temp_bg.composite_tier_contributions.build(
              composite_rating_tier: ctc.composite_rating_tier,
              employer_contribution_percent: ctc.employer_contribution_percent,
              offered: ctc.offered
            )
          end
          temp_bg.build_estimated_composite_rates
        end

        temp_bg.set_bounding_cost_plans
        temp_bg
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
        @qhps ||= ::Products::QhpCostShareVariance.find_qhp_cost_share_variances(requested_plans, plan_design_proposal.effective_date.year, "Health")
      end

      def visit_types
        @visit_types ||= ::Products::Qhp::VISIT_TYPES
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
          :plan_option_kind,
          relationship_benefits_attributes: [:relationship, :premium_pct, :offered],
          composite_tier_contributions_attributes: [:composite_rating_tier, :employer_contribution_percent, :offered]
        )
      end
    end
  end
end
