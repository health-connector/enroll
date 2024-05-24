module Notifier
  class ApplicationController < ActionController::Base
    include Pundit
    include ::L10nHelper
    include ::FileUploadHelper
    layout "notifier/single_column"

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
  end
end
