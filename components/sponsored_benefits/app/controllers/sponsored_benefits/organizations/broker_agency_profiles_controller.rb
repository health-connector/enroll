require_dependency "sponsored_benefits/application_controller"

module SponsoredBenefits
  class Organizations::BrokerAgencyProfilesController < ApplicationController
    include Config::AcaConcern
    include DataTablesAdapter

    before_action :find_broker_agency_profile, only: [:employers]

    def employers
      @broker_role = current_user.person.broker_role if current_user&.person
      if general_agency_is_enabled?
        @general_agency_profiles = GeneralAgencyProfile.all_by_broker_role(@broker_role, approved_only: true) if @broker_role.present?
        @datatable = ::Effective::Datatables::BrokerAgencyEmployerDatatable.new(profile_id: @broker_agency_profile._id, general_agency_is_enabled: "true")
      else
        @datatable = ::Effective::Datatables::BrokerAgencyEmployerDatatable.new(profile_id: @broker_agency_profile._id)
      end
    end

  private

    def find_broker_agency_profile
      @broker_agency_profile = ::BenefitSponsors::Organizations::BrokerAgencyProfile.find(params[:id])
      @id = @broker_agency_profile.id
    end
  end
end
