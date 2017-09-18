class Exchanges::EmployersController < ApplicationController
  before_action :check_hbx_staff_role, except: [:request_help, :show, :assister_index, :family_index, :update_cancel_enrollment, :update_terminate_enrollment]
  layout 'single_column'

  def new
    @organization = Forms::EmployerProfile.new
    get_sic_codes
  end

  def create
    params.permit!
    @organization = Forms::EmployerProfile.new(params[:organization])
    organization_saved = false
    new_user = User.create!(email: params[:organization][:email], oim_id: params[:organization][:email], password: 'ChangeMe123!')
    begin
      organization_saved, pending = @organization.save(new_user, params[:employer_id])
    rescue Exception => e
      flash[:error] = e.message
      get_sic_codes
      new_user.destroy!
      render action: "new"
      return
    end
    if organization_saved
      @person = @organization.person
      create_sso_account(new_user, new_user.person, 15, "employer") do
        if pending
          # flash[:notice] = 'Your Employer Staff application is pending'
          render action: 'show_pending'
        else
          flash[:success] = "Employer Successfully Created"
          redirect_to exchanges_hbx_profiles_root_path
        end
      end
    else
      new_user.destroy!
      get_sic_codes
      render action: "new"
    end
  end

  private

  def check_hbx_staff_role
    unless current_user.has_hbx_staff_role?
      redirect_to root_path, :flash => { :error => "You must be an HBX staff member" }
    end
  end

  def get_sic_codes
    @grouped_options = {}
    SicCode.all.group_by(&:industry_group_label).each do |industry_group_label, sic_codes|
      @grouped_options[industry_group_label] = sic_codes.collect{|sc| ["#{sc.sic_label} - #{sc.sic_code}", sc.sic_code]}
    end
  end
end
