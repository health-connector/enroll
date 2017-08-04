class Users::PasswordsController < Devise::PasswordsController

  protected

  def after_resetting_password_path_for(resource_name)
    root_url
  end
end