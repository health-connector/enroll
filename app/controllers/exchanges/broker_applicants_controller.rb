class Exchanges::BrokerApplicantsController < ApplicationController
  include Exchanges::BrokerApplicantsHelper

  before_action :check_hbx_staff_role
  before_action :find_broker_applicant, only: [:edit, :update]

  def index
    @people = Person.exists(broker_role: true).broker_role_having_agency

    status_params = params.permit(:status)
    @status = BrokerRole::BROKER_ROLE_STATUS_TYPES.include?(status_params[:status]) ? status_params[:status] : 'applicant'

    # Status Filter can be applicant | certified | deceritifed | denied | all
    @people = @people.send("broker_role_#{@status}") if @people.respond_to?("broker_role_#{@status}")
    @page_alphabets = page_alphabets(@people, "last_name")

    if params[:page].present?
      page_no = cur_page_no(@page_alphabets.first)
      @broker_applicants = @people.where("last_name" => /^#{Regexp.escape(page_no)}/i)
    else
      @broker_applicants = sort_by_latest_transition_time(@people).limit(20).entries
    end

    respond_to do |format|
      format.js
    end
  end

  def edit
    respond_to do |format|
      format.js
    end
  end

  def update
    broker_role = @broker_applicant.broker_role
    if params[:person] && params[:person][:broker_role_attributes] && params[:person][:broker_role_attributes][:reason]
      broker_role.update_attributes(:reason => params[:person][:broker_role_attributes][:reason])
    end
    if params['deny']
      broker_role.deny!
      flash[:notice] = "Broker applicant denied."
    elsif params['update']
      all_carrier_appointments = BrokerRole::BROKER_CARRIER_APPOINTMENTS.stringify_keys
      permitted_params = params.require(:person).require(:broker_role_attributes).permit(:carrier_appointments => {}).to_h
      all_carrier_appointments.merge!(permitted_params[:carrier_appointments]) if permitted_params[:carrier_appointments]
      params[:person][:broker_role_attributes][:carrier_appointments] = all_carrier_appointments
      broker_role.update(params.require(:person).require(:broker_role_attributes).permit!.except(:id))
    elsif params['decertify']
      broker_role.decertify!
      flash[:notice] = "Broker applicant decertified."
    elsif params['recertify']
      broker_role.recertify!
      flash[:notice] = "Broker applicant is now approved."
    elsif params['pending']
      broker_carrier_appointments
      broker_role.update(params.require(:person).require(:broker_role_attributes).permit!.except(:id))
      broker_role.pending!
      flash[:notice] = "Broker applicant is now pending."
    else
      broker_carrier_appointments
      broker_role.update(params.require(:person).require(:broker_role_attributes).permit!.except(:id))
      broker_role.approve!
      broker_role.reload

      if broker_role.is_primary_broker?
        broker_role.broker_agency_profile.approve! if broker_role.broker_agency_profile.aasm_state !=  "is_approved"
        staff_role = broker_role.person.broker_agency_staff_roles[0]
        staff_role.broker_agency_accept! if staff_role
      end
      
      if broker_role.agency_pending?
        send_secure_message_to_broker_agency(broker_role) if broker_role.broker_agency_profile
      end
      flash[:notice] = "Broker applicant approved successfully."
    end

    redirect_to "/exchanges/hbx_profiles"
  end

  private

  def broker_carrier_appointments
    all_carrier_appointments = BrokerRole::BROKER_CARRIER_APPOINTMENTS.stringify_keys
    broker_carrier_appointments_enabled = Settings.aca.broker_carrier_appointments_enabled
    unless broker_carrier_appointments_enabled
      permitted_params = params.require(:person).require(:broker_role_attributes).permit(:carrier_appointments => {}).to_h
      all_carrier_appointments.merge!(permitted_params[:carrier_appointments]) if permitted_params[:carrier_appointments]
      params[:person][:broker_role_attributes][:carrier_appointments] = all_carrier_appointments
    else
      params[:person][:broker_role_attributes][:carrier_appointments] = all_carrier_appointments.each{ |key, _| all_carrier_appointments[key] = "true" }
    end
  end

  def send_secure_message_to_broker_agency(broker_role)
    hbx_admin = HbxProfile.all.first
    broker_agency = broker_role.broker_agency_profile

    subject = "Received new broker application - #{broker_role.person.full_name}"
    body = "<br><p>Following are broker details<br>Broker Name : #{broker_role.person.full_name}<br>Broker NPN  : #{broker_role.npn}</p>"
    secure_message(hbx_admin, broker_agency, subject, body)
  end

  def find_broker_applicant
    @broker_applicant = Person.find(BSON::ObjectId.from_string(params[:id]))
  end

  def check_hbx_staff_role
    unless current_user.has_hbx_staff_role?
      redirect_to exchanges_hbx_profiles_root_path, :flash => { :error => "You must be an HBX staff member" }
    end
  end
end