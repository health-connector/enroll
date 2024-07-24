class Users::OrphansController < ApplicationController
  layout "two_column"
  before_action :set_orphan, only: [:show, :destroy]

  def index
    authorize User, :staff_can_access_user_account_tab?
    @orphans = User.orphans
  end

  def show
  end

  def destroy
    authorize User, :staff_can_access_user_account_tab?
    @orphan.destroy
    respond_to do |format|
      format.html { redirect_to exchanges_hbx_profiles_path, notice: 'Orphan user account was successfully deleted.' }
      format.json { head :no_content }
    end
  end

private
    # Use callbacks to share common setup or constraints between actions.
    def set_orphan
      @orphan = User.find(params[:id])
    end

end
