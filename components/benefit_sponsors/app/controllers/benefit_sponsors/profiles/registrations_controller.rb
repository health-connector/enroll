require_dependency "benefit_sponsors/application_controller"

module BenefitSponsors
  module Profiles
    class RegistrationsController < ::BenefitSponsors::ApplicationController
      include BenefitSponsors::Concerns::ProfileRegistration

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      layout 'two_column', :only => :edit

      def new
        @agency = BenefitSponsors::Organizations::OrganizationForms::RegistrationForm.for_new(profile_type: profile_type, portal: params[:portal])
        if @agency.blank?
          authorize_user!
        else
          authorize @agency
          authorize @agency, :redirect_home?
          set_ie_flash_by_announcement unless is_employer_profile?
        end

        respond_to do |format|
          format.html
          format.js
        end
      end

      def create
        @logger = Logger.new("#{Rails.root}/log/registrations_controller.log")
        @agency = BenefitSponsors::Organizations::OrganizationForms::RegistrationForm.for_create(registration_params)
        authorize @agency
        @logger.info("*** Auth successful***")
        begin
          saved, result_url = @agency.save
          @logger.info("*** Registration Saved: #{saved}, result_url: #{result_url} ***")
          result_url = send(result_url)
          if saved
            if is_employer_profile?
              person = current_person
              @logger.info("*** creating SSO account user - #{current_user&.id} ***")
              create_sso_account(current_user, current_person, 15, "employer") do
              end
            else
              flash[:notice] = "Your registration has been submitted. A response will be sent to the email address you provided once your application is reviewed."
            end
            @logger.info("*** Action complete, final result_url #{result_url} ***")
            redirect_to result_url
            return
          end
        rescue Exception => e
          @logger.error("*** Exception in registrations controller: message: #{e.message} and backtrace: #{e.backtrace&.join("\n")} ***")
          flash[:error] = e.message
        end
        params[:profile_type] = profile_type
        @logger.error("*** Errors in registrations controller: #{@agency.errors.full_messages} ***")
        render default_template, :flash => { :error => @agency.errors.full_messages }
      end

      def edit
        @agency = BenefitSponsors::Organizations::OrganizationForms::RegistrationForm.for_edit(profile_id: params[:id])
        authorize @agency
      end

      def update
        @agency = BenefitSponsors::Organizations::OrganizationForms::RegistrationForm.for_update(registration_params)
        authorize @agency
        updated, result_url = @agency.update
        result_url = send(result_url)
        if updated
          flash[:notice] = 'Employer successfully Updated.' if is_employer_profile?
          flash[:notice] = 'Broker Agency Profile successfully Updated.' if is_broker_profile?
        else
          org_error_msg = @agency.errors.full_messages.join(",").humanize if @agency.errors.present?

          flash[:error] = "Employer information not saved. #{org_error_msg}." if is_employer_profile?
          flash[:error] = "Broker Agency information not saved. #{org_error_msg}." if is_broker_profile?
        end
        redirect_to result_url
      end

      def counties_for_zip_code
        @counties = BenefitMarkets::Locations::CountyZip.where(zip: params[:zip_code]).pluck(:county_name).uniq

        render json: @counties
      end

      private

      def profile_type
        @profile_type = params[:profile_type] || params.dig(:agency, :profile_type) || @agency.profile_type
      end

      def default_template
        :new
      end

      def is_employer_profile?
        profile_type == "benefit_sponsor"
      end

      def is_broker_profile?
        profile_type == "broker_agency"
      end

      def registration_params
        current_user_id = current_user.present? ? current_user.id : nil
        params[:agency].merge!({
                                 :profile_id => params["id"],
                                 :current_user_id => current_user_id
                               })
        params[:agency].permit!
      end

      def organization_params
        params[:agency][:organization].permit!
      end

      def current_person
        current_user.reload # devise current user not loading changes
        current_user.person
      end

      def user_not_authorized(exception)
        action = exception.query.to_sym

        case action
        when :redirect_home?
          if current_user
            redirect_to send(:agency_home_url, exception.record.profile_id)
          else
            session[:custom_url] = main_app.new_user_session_path
            super
          end
        when :new?
          params_hash = params.permit(:profile_type, :controller, :action)
          session[:portal] = url_for(params_hash)
          redirect_to send(:sign_up_url)
        else
          session[:custom_url] = main_app.new_user_registration_path unless current_user
          super
        end
      end
    end
  end
end
