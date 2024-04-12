module IndividualMarket
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    include Pundit

    helper IndividualMarket::Engine.helpers

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from ActionController::InvalidAuthenticityToken, :with => :bad_token_due_to_session_expired

    protected

    def set_current_person(required: true)
      if current_user.try(:person).try(:agent?) && session[:person_id].present?
        @person = Person.find(session[:person_id])
      else
        @person = current_user.person
      end
      redirect_to logout_saml_index_path if required && !set_current_person_succeeded?
    end

    def set_current_person_succeeded?
      return true if @person
      message = {}
      message[:message] = 'Application Exception - person required'
      message[:session_person_id] = session[:person_id]
      message[:user_id] = current_user.id
      message[:oim_id] = current_user.oim_id
      message[:url] = request.original_url
      log(message, :severity=>'error')
      return false
    end

    private

    def broker_agency_or_general_agency?
      @profile_type == "broker_agency" || @profile_type == "general_agency"
    end

    def user_not_authorized(exception)
      policy_name = exception.policy.class.to_s.underscore
      flash[:error] = "Access not allowed for #{exception.query}, (Pundit policy)" unless broker_agency_or_general_agency?
      respond_to do |format|
        format.json { render nothing: true, status: :forbidden }
        format.html { redirect_to(session[:custom_url] || request.referrer || main_app.root_path)}
        format.js   { render nothing: true, status: :forbidden }
      end
    end

    def bad_token_due_to_session_expired
      flash[:warning] = "Session expired."
      respond_to do |format|
        format.html { redirect_to main_app.root_path}
        format.js   { render text: "window.location.assign('#{main_app.root_path}');"}
        format.json { render json: { :token_expired => root_url }, status: :unauthorized }
      end
    end
  end
end
