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
        benefit_group = plan_design_proposal.active_benefit_group
        employer_costs_data = calculate_employer_costs
        @qhps = qhps.each do |qhp|
          qhp[:total_employee_cost] = if benefit_group && employer_costs_data[qhp.plan.id]
                                        employer_costs_data[qhp.plan.id]
                                      else
                                        0.00
                                      end
        end
        respond_to do |format|
          format.csv do
            send_data(::Products::Qhp.csv_for(qhps, visit_types), type: csv_content_type, filename: "comparsion_plans.csv")
          end
        end
      end

      private

      helper_method :plan_design_form, :plan_design_organization, :plan_design_proposal, :visit_types, :qhps, :employer_costs

      def employer_costs
        @employer_costs ||= calculate_employer_costs
      end

      def calculate_employer_costs
        active_benefit_group = plan_design_proposal.active_benefit_group
        return {} unless active_benefit_group

        # Reload to get fresh data
        active_benefit_group.reload

        qhps.each_with_object({}) do |qhp, costs|

          next unless qhp.plan.present?

          # Build a temporary benefit group with this plan as reference
          temp_benefit_group = build_temp_benefit_group_for_plan(active_benefit_group, qhp.plan)

          # Initialize service with the temporary benefit_group
          service = SponsoredBenefits::Services::PlanCostService.new(benefit_group: temp_benefit_group)

          # Calculate employer cost
          employer_cost = service.monthly_employer_contribution_amount

          costs[qhp.plan.id] = employer_cost || 0.00
        rescue StandardError => e
          Rails.logger.error "Error for plan #{qhp.plan&.id}: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          costs[qhp.plan.id] = 0.00 if qhp.plan.present?
        end
      end

      def build_temp_benefit_group_for_plan(active_benefit_group, plan)
        sponsorship = plan_design_proposal.profile.benefit_sponsorships.first
        benefit_application = sponsorship.benefit_applications.first

        # Build temporary benefit group with the comparison plan as reference
        temp_bg = benefit_application.benefit_groups.build(
          reference_plan_id: plan.id,
          plan_option_kind: active_benefit_group.plan_option_kind
        )

        # Copy relationship benefits from active benefit group
        active_benefit_group.relationship_benefits.each do |rb|
          temp_bg.relationship_benefits.build(
            relationship: rb.relationship,
            premium_pct: rb.premium_pct,
            offered: rb.offered
          )
        end

        # Copy composite tier contributions if sole_source
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
    end
  end
end
