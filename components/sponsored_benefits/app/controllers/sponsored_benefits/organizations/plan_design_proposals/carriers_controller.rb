module SponsoredBenefits
  module Organizations
    class PlanDesignProposals::CarriersController < ApplicationController

      def index
        @carrier_names = ::Organization.load_carriers(
                            primary_office_location: plan_design_organization.primary_office_location,
                            selected_carrier_level: selected_carrier_level,
                            active_year: active_year,
                            kind: kind,
                            quote_effective_date: quote_effective_date
                            )
      end

      private
      helper_method :selected_carrier_level, :plan_design_organization, :active_year, :kind, :quote_effective_date, :plan_design_proposal

      def selected_carrier_level
        @selected_carrier_level ||= params[:selected_carrier_level]
      end

      def plan_design_organization
        @plan_design_organization ||= PlanDesignOrganization.find(params[:plan_design_organization_id])
      end

      def plan_design_proposal
        @plan_design_proposal ||= SponsoredBenefits::Organizations::PlanDesignProposal.find(params[:plan_design_proposal_id])
      end

      def active_year
        params[:active_year]
      end

      def kind
        params[:kind]
      end

      def quote_effective_date
        params[:quote_effective_date]
      end
    end
  end
end
