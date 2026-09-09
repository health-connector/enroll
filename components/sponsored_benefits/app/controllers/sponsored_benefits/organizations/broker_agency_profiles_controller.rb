require_dependency "sponsored_benefits/application_controller"

module SponsoredBenefits
  class Organizations::BrokerAgencyProfilesController < ApplicationController
    include Config::AcaConcern
    include DataTablesAdapter
    include ::Datatables::FragmentRendering
    include ::Datatables::CsvStreaming

    before_action :find_broker_agency_profile, only: [:employers, :employers_datatable]

    def employers
      @broker_role = current_user.person.broker_role if current_user&.person
      if EnrollRegistry.feature_enabled?(:refactored_datatables)
        @employers_datatable_locals = datatable_locals(broker_agency_employers_table, url: employers_datatable_url)
      else
        @datatable = ::Effective::Datatables::BrokerAgencyEmployerDatatable.new(profile_id: @broker_agency_profile._id)
      end
    end

    # Renders the Employers table fragment for Stimulus redraws and streams its
    # CSV export. The quote-management check applied here is the one the legacy
    # datatable ran on every draw; the page action itself carries none.
    def employers_datatable
      raise ActionController::RoutingError, 'Not Found' unless EnrollRegistry.feature_enabled?(:refactored_datatables)

      authorize @broker_agency_profile, :employers_datatable?, policy_class: ::SponsoredBenefits::BrokerAgencyPlanDesignOrganizationPolicy
      table = broker_agency_employers_table
      respond_to do |format|
        format.html { render_datatable_fragment(table, url: employers_datatable_url) }
        format.csv do
          stream_datatable_csv(filename: 'broker_agency_employers.csv',
                               headers: table.csv_headers,
                               rows: datatable_csv_rows(table, datatable_scoped(table)))
        end
      end
    end

  private

    def broker_agency_employers_table
      ::SponsoredBenefits::Datatables::BrokerAgencyEmployersTable.new(@broker_agency_profile)
    end

    def employers_datatable_url
      employers_datatable_organizations_broker_agency_profile_path(@broker_agency_profile)
    end

    def find_broker_agency_profile
      @broker_agency_profile = ::BenefitSponsors::Organizations::BrokerAgencyProfile.find(params[:id])
      @id = @broker_agency_profile.id
    end
  end
end
