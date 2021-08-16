class WelcomeController < ApplicationController
  skip_before_filter :require_login

  def show_hints
    current_user.hints = !current_user.hints
    current_user.save
    render json: nil, status: :ok
  end

  def index
    respond_to do |format|
      format.html
      format.js
      format.any { head :ok }
    end
  end

  def form_template
    # created for generic form template access at '/templates/form-template'
  end
end
