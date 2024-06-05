module BenefitSponsors
  module Profiles
    module Employers
      class BrokerAgencyController < ::BenefitSponsors::ApplicationController
        before_action :find_employer
        before_action :find_broker_agency, :except => [:index, :active_broker]

        def index
          authorize @employer_profile

          @filter_criteria = params.permit(:q, :working_hours, :languages => [])

          if @filter_criteria.empty?
            @orgs = BenefitSponsors::Organizations::Organization.approved_broker_agencies.broker_agencies_by_market_kind(['both', 'shop'])
            @page_alphabets = page_alphabets(@orgs, "legal_name")

            if params[:page].present?
              @page_alphabet = cur_page_no(@page_alphabets.first)
              @organizations = @orgs.where("legal_name" => /^#{Regexp.escape(@page_alphabet)}/i)
            else
              @organizations = @orgs.limit(12).to_a
            end
            @broker_agency_profiles = Kaminari.paginate_array(@organizations.map(&:broker_agency_profile).uniq).page(params[:organization_page] || 1).per(10)
          else
            results = BenefitSponsors::Organizations::Organization.broker_agencies_with_matching_agency_or_broker(@filter_criteria)
            if results.first.is_a?(Person)
              @filtered_broker_roles  = results.map(&:broker_role)
              @broker_agency_profiles = Kaminari.paginate_array(results.map{|broker| broker.broker_role.broker_agency_profile}.uniq).page(params[:organization_page] || 1).per(10)
            else
              @broker_agency_profiles = Kaminari.paginate_array(results.map(&:broker_agency_profile).uniq).page(params[:organization_page] || 1).per(10)
            end
          end

          respond_to do |format|
            format.js
          end
        end

        def show
          authorize @employer_profile
        end

        def active_broker
          authorize @employer_profile

          @broker_agency_account = @employer_profile.active_broker_agency_account
        end

        def create
          authorize @employer_profile
          begin
            @broker_management_form = BenefitSponsors::Organizations::OrganizationForms::BrokerManagementForm.for_create(sanitized_params)
            @broker_management_form.save
            flash[:notice] = "Your broker has been notified of your selection and should contact you shortly. You can always call or email them directly. If this is not the broker you want to use, select 'Change Broker'."
            redirect_to profiles_employers_employer_profile_path(@employer_profile, tab: 'brokers')
          rescue StandardError => e
            error_msgs = @broker_management_form.errors.map(&:full_messages) if @broker_management_form.errors
            Rails.logger.warn("Unable to create broker. Error Messages: #{error_msgs}, Error: #{e}")
            redirect_back(fallback_location: main_app.root_path, :flash => {error: error_msgs})
          end
        end

        def terminate
          authorize @employer_profile

          begin
            @broker_management_form = BenefitSponsors::Organizations::OrganizationForms::BrokerManagementForm.for_terminate(sanitize_terminate_params)

            if @broker_management_form.terminate && @broker_management_form.direct_terminate
              flash[:notice] = "Broker terminated successfully."
              redirect_to profiles_employers_employer_profile_path(@employer_profile, tab: "brokers")
            else
              redirect_to profiles_employers_employer_profile_path(@employer_profile)
            end
          rescue StandardError => e
            Rails.logger.warn("Unable to terminate broker. Error: #{e}")
            flash[:error] = "Unable to terminate broker. Please contact customer service at #{Settings.contact_center.phone_number}."
            redirect_to profiles_employers_employer_profile_path(@employer_profile, tab: 'brokers')
          end
        end

        private

        def sanitized_params
          params.permit(:broker_agency_id,
                        :broker_role_id,
                        :employer_profile_id)
        end

        def sanitize_terminate_params
          params.permit(:direct_terminate, :termination_date, :employer_profile_id, :broker_agency_id)
        end

        def find_employer
          @employer_profile = find_profile(params["employer_profile_id"])
        end

        def find_broker_agency
          id = params[:id] || params[:broker_agency_id]
          @broker_agency_profile = find_profile(id)
        end

        def find_profile(id)
          BenefitSponsors::Organizations::Profile.find(id)
        end
      end
    end
  end
end
