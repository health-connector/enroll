class UsersController < ApplicationController

  def confirm_lock
    params.permit!
    @user = User.find(params[:id])
    @user_id  = params[:user_action_id]
  end

  def lockable
    user = User.find(params[:id])
    authorize User, :lockable?
    user.lock!
    redirect_to user_account_index_exchanges_hbx_profiles_url, notice: "User #{user.person.full_name} is successfully #{user.lockable_notice}."
  rescue Exception => e
    redirect_to user_account_index_exchanges_hbx_profiles_url, alert: "You are not authorized for this action."
  end

  def login_history
    @user = User.find(params[:id])
    @user_login_history = SessionIdHistory.for_user(user_id: @user.id).order('created_at DESC').page(params[:page]).per(15)
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    @user.update_attributes(email_update_params)
  end

  private

  def email_update_params
    params.require(:user).permit(:email)
  end

end
