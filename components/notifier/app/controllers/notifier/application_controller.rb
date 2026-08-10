module Notifier
  class ApplicationController < ActionController::Base
    include Pundit::Authorization
    include ::L10nHelper
    include ::FileUploadHelper
    layout "notifier/single_column"

    protect_from_forgery with: :exception, prepend: true

    rescue_from ActionController::InvalidAuthenticityToken, :with => :bad_token_due_to_session_expired

    private

    def bad_token_due_to_session_expired
      flash[:warning] = "Session expired."
      respond_to do |format|
        format.html { redirect_to root_path}
        format.js   { render text: "window.location.assign('#{root_path}');"}
        format.json { render json: { :token_expired => root_url }, status: :unauthorized }
      end
    end

    def user_not_authorized(_exception)
      flash[:error] = t('exchange.not_authorized')
      safe_url = url_from(session[:custom_url])
      respond_to do |format|
        format.json { render nothing: true, status: :forbidden }
        format.html do
          if safe_url
            redirect_to(safe_url)
          else
            redirect_back(fallback_location: main_app.root_path, allow_other_host: false)
          end
        end
        format.js   { render plain: "window.location.assign('#{safe_url || main_app.root_path}');" }
      end
    end
  end
end
