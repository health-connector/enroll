class Users::PasswordsController < Devise::PasswordsController
  # include ActionView::Helpers::TranslationHelper
  include L10nHelper

  before_action :confirm_identity, only: [:create]

  rescue_from 'Mongoid::Errors::DocumentNotFound', with: :user_not_found

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      resource.security_question_responses.destroy_all
      show_generic_forgot_password_text

      respond_to do |format|
        format.html { respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name)) }
        format.js
      end
    else
      respond_with(resource)
    end
  end

  def user_not_found
    show_generic_forgot_password_text
    redirect_to new_user_password_path
  end

  private

  def show_generic_forgot_password_text
    return unless EnrollRegistry.feature_enabled?(:generic_forgot_password_text)

    flash[:notice] = l10n('devise.passwords.new.generic_forgot_password_text')
  end

  def user
    @user ||= User.find_by(email: params[:user][:email])
  end

  def confirm_identity
    return true if current_user&.has_role?('hbx_staff')

    return if user.identity_confirmed_token == params[:user][:identity_confirmed_token]

    flash[:error] = "Something went wrong, please try again"
    redirect_to new_user_password_path
    false
  end

  protected

  def after_resetting_password_path_for(resource_name)
    root_url
    resource_name.last_portal_visited.present? ? resource_name.last_portal_visited : root_url
  end
end
