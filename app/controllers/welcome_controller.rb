class WelcomeController < ApplicationController
  skip_before_action :require_login
  before_action :set_cookie_attributes, only: [:index]

  def show_hints
    authorize current_user, :view?

    current_user.hints = !current_user.hints
    current_user.save
    render json: nil, status: :ok
  end

  def index; end

  private

  def set_cookie_attributes
    response.headers['Set-Cookie'] = "_session_id=#{session.id}; SameSite=Strict; Secure=true; HttpOnly"
    response.headers['Strict-Transport-Security'] = "max-age=31536000; includeSubDomains; preload"
  end
end
