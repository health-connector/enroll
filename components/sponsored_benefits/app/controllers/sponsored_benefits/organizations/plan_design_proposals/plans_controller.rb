module SponsoredBenefits
  module Organizations
    class PlanDesignProposals::PlansController < ApplicationController

      def index
        offering_query = ::Queries::EmployerPlanOfferings.new(plan_design_organization)
        @plans = case selected_carrier_level
          when "single_carrier"
            offering_query.single_carrier_offered_health_plans(params[:carrier_id], params[:active_year])
          when "metal_level"
            offering_query.metal_level_offered_health_plans(params[:metal_level], params[:active_year])
          when "single_plan"
            offering_query.send "single_option_offered_#{kind}_plans", params[:carrier_id], params[:active_year]
          when "sole_source"
            offering_query.sole_source_offered_health_plans(params[:carrier_id], params[:active_year])
          end
        @plans = @plans.select{|a| a.premium_tables.by_date(params[:quote_effective_date].to_date).present? }
        @search_options = ::Plan.search_options(@plans)
        @search_option_titles = {
                'plan_type': 'HMO / PPO',
                'plan_hsa': 'HSA - Compatible',
                'metal_level': 'Metal Level',
                'plan_deductible': 'Individual deductible (in network)'
              }

        @search_option_titles.merge!({is_pvp: "Premium Value Plan"}) if ::EnrollRegistry.feature_enabled?(:premium_value_products)
        @plan_deductibles = plan_deductible_values(@plans)
      end

      private
      helper_method :selected_carrier_level, :plan_design_organization, :carrier_profile, :carriers_cache,
                    :kind, :plan_deductible_values, :plan_design_proposal, :rating_area, :quote_effective_date

      def selected_carrier_level
        @selected_carrier_level ||= params[:selected_carrier_level]
      end

      def quote_effective_date
        @quote_effective_date ||= params[:quote_effective_date]
      end

      def plan_design_organization
        @plan_design_organization ||= PlanDesignOrganization.find(params[:plan_design_organization_id])
      end

      def plan_design_proposal
        @plan_design_proposal ||= SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:plan_design_proposal_id])
      end

      def rating_area
        @rating_area ||= plan_design_proposal.profile.rating_area
      end

      def carrier_profile
        @carrier_profile ||= ::CarrierProfile.find(params[:carrier_id])
      end

      def carriers_cache
        @carriers_cache ||= ::CarrierProfile.all.inject({}) do |carrier_hash, carrier_profile|
          carrier_hash[carrier_profile.id] = carrier_profile.legal_name
          carrier_hash
        end
      end

      def kind
        params[:kind]
      end

      def plan_deductible_values(plans)
        plan_deductibles = {}
        plans.each do |plan|
          deductible = plan.medical_individual_deductible == "N/A" ? "N/A" : "$#{plan.medical_individual_deductible}"
          family_deductible = plan.medical_family_deductible == "N/A" ? "N/A" : "$#{plan.medical_family_deductible}"
          rx_deductible = plan.rx_individual_deductible == "N/A" ? "N/A" : "$#{plan.rx_individual_deductible}"
          rx_family_deductible = plan.rx_family_deductible == "N/A" ? "N/A" : "$#{plan.rx_family_deductible}"
          plan_deductibles[plan.id] = {deductible: deductible, family_deductible: family_deductible, rx_deductible: rx_deductible, rx_family_deductible: rx_family_deductible}
        end

        plan_deductibles
      end
    end
  end
end
