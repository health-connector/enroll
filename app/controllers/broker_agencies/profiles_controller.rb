class BrokerAgencies::ProfilesController < ApplicationController
  include Acapi::Notifiers
  include ::Config::AcaConcern
  include ::DataTablesAdapter

  before_action :find_broker_agency_profile, only: [:edit, :update, :employers, :assign, :update_assign, :employer_datatable, :manage_employers, :general_agency_index, :clear_assign_for_employer, :set_default_ga, :assign_history]
  before_action :check_general_agency_profile_permissions_assign, only: [:assign, :update_assign, :clear_assign_for_employer, :assign_history]
  before_action :check_general_agency_profile_permissions_set_default, only: [:set_default_ga]
  before_action :redirect_unless_general_agency_is_enabled?, only: [:assign, :update_assign]
  layout 'single_column'

  EMPLOYER_DT_COLUMN_TO_FIELD_MAP = {
    "2"     => "legal_name",
    "4"     => "employer_profile.aasm_state",
    "5"     => "employer_profile.plan_years.start_on"
  }

  def update_assign
    params[:general_agency_id] = params[:employers_general_agency_id] if params[:employers_general_agency_id]
    authorize @broker_agency_profile, :set_default_ga?
    if params[:general_agency_id].present? || params[:employer_ids].present? && params[:bulk_actions_resources].present?
      general_agency_profile = GeneralAgencyProfile.find(params[:general_agency_id])
      case params[:type]
      when 'fire'
        params[:employer_ids].each do |employer_id|
          employer_profile = EmployerProfile.find(employer_id) rescue next

          employer_profile.fire_general_agency!
          send_general_agency_assign_msg(general_agency_profile, employer_profile, 'Terminate')
        end
        notice = "Fire these employers successful."
      else
        employer_ids = if params.key? :bulk_actions_resources
        params[:bulk_actions_resources].map do |pdo_id|
          SponsoredBenefits::Organizations::PlanDesignOrganization.find(pdo_id).employer_profile.id
        end
        else
          params[:employer_ids]
        end
        employer_ids.each do |employer_id|
          employer_profile = EmployerProfile.find(employer_id) rescue nil
          if employer_profile.present? #FIXME : Please move me to model
            broker_role_id = current_user.person.broker_role.id rescue nil
            broker_role_id ||= @broker_agency_profile.primary_broker_role_id
            employer_profile.hire_general_agency(general_agency_profile, broker_role_id)
            employer_profile.save
            send_general_agency_assign_msg(general_agency_profile, employer_profile, 'Hire')
            general_agency_profile.general_agency_hired_notice(employer_profile) #GA notice when broker Assign a GA to employers
          end
        end
        flash.now[:notice] ="Assign successful."
        if params["from_assign"] == "true"
          assign # calling this method as the latest copy of objects are needed.
          render "assign" and return
        else
          employers # calling this method as the latest copy of objects are needed.
          render "update_assign" and return
        end
      end
    elsif params["commit"].try(:downcase) == "clear assignment"
      employer_ids = if params.key? :bulk_actions_resources
      params[:bulk_actions_resources].map do |pdo_id|
        SponsoredBenefits::Organizations::PlanDesignOrganization.find(pdo_id).employer_profile.id
      end
      else
        params[:employer_ids]
      end
      employer_ids.each do |employer_id|
        employer_profile = EmployerProfile.find(employer_id) rescue next
        if employer_profile.general_agency_profile.present?
          send_general_agency_assign_msg(employer_profile.general_agency_profile, employer_profile, 'Terminate')
          employer_profile.fire_general_agency!
        end
      end
      notice = "Unassign successful."
    end
    redirect_to broker_agencies_profile_path(@broker_agency_profile), flash: {notice: notice}
  end

  def clear_assign_for_employer
    @broker_role = current_user.person.broker_role || nil
    @general_agency_profiles = GeneralAgencyProfile.all_by_broker_role(@broker_role, approved_only: true)
    @employer_profile = EmployerProfile.find(params[:employer_id]) rescue nil
    authorize @employer_profile, :fire_general_agency?
    if @employer_profile.present?
      send_general_agency_assign_msg(@employer_profile.general_agency_profile, @employer_profile, 'Terminate')
      @employer_profile.fire_general_agency!
    end
  end

  def agency_messages
    @sent_box = true
    @broker_agency_profile = current_user.person.broker_agency_staff_roles.first.broker_agency_profile
  end

  def redirect_to_show(broker_agency_profile_id)
    redirect_to broker_agencies_profile_path(id: broker_agency_profile_id)
  end

  private

  def broker_profile_params
    return unless params[:organization]

    params.fetch(:organization,{}).permit(
      :legal_name,
      :dba,
      :home_page,
      :office_locations_attributes => [
        :address_attributes => [:kind, :address_1, :address_2, :city, :state, :zip],
        :phone_attributes => [:kind, :area_code, :number, :extension],
        :email_attributes => [:kind, :address]
      ]
    )
  end

  def languages_spoken_params
    params.require(:organization).permit(
      :accept_new_clients,
      :working_hours,
      :languages_spoken => []
    )
  end

  def person_profile_params
    params.require(:organization).permit(:first_name, :last_name, :dob)
  end

  def sanitize_broker_profile_params
    params[:organization][:office_locations_attributes].each do |key, location|
      params[:organization][:office_locations_attributes].delete(key) unless location['address_attributes']
      location.delete('phone_attributes') if (location['phone_attributes'].present? && location['phone_attributes']['number'].blank?)
    end
  end

  def find_broker_agency_profile
    @broker_agency_profile = BrokerAgencyProfile.find(params[:id])
    authorize @broker_agency_profile, :access_to_broker_agency_profile?
  end

  def check_broker_agency_staff_role
    if current_user.has_broker_agency_staff_role?
      redirect_to broker_agencies_profile_path(:id => current_user.person.broker_agency_staff_roles.first.broker_agency_profile_id)
    elsif current_user.has_broker_role?
      redirect_to broker_agencies_profile_path(id: current_user.person.broker_role.broker_agency_profile_id.to_s)
    else
      flash[:notice] = "You don't have a Broker Agency Profile associated with your Account!! Please register your Broker Agency first."
    end
  end

  def send_general_agency_assign_msg(general_agency, employer_profile, status)
    subject = "You are associated to #{employer_profile.legal_name}- #{general_agency.legal_name} (#{status})"
    body = "<br><p>Associated details<br>General Agency : #{general_agency.legal_name}<br>Employer : #{employer_profile.legal_name}<br>Status : #{status}</p>"
    secure_message(@broker_agency_profile, general_agency, subject, body)
    secure_message(@broker_agency_profile, employer_profile, subject, body)
  end

  def update_ga_for_employers(broker_agency_profile, old_default_ga=nil)
    return if broker_agency_profile.blank?

    orgs = Organization.by_broker_agency_profile(broker_agency_profile.id)
    employer_profiles = orgs.map {|o| o.employer_profile}
    if broker_agency_profile.default_general_agency_profile.blank?
      employer_profiles.each do |employer_profile|
        general_agency = employer_profile.active_general_agency_account.general_agency_profile rescue nil
        if general_agency && general_agency == old_default_ga
          send_general_agency_assign_msg(general_agency, employer_profile, 'Terminate')
          employer_profile.fire_general_agency!
        end
      end
    else
      employer_profiles.each do |employer_profile|
        employer_profile.hire_general_agency(broker_agency_profile.default_general_agency_profile, broker_agency_profile.primary_broker_role_id)
        employer_profile.save
        send_general_agency_assign_msg(broker_agency_profile.default_general_agency_profile, employer_profile, 'Hire')
      end
    end
  end

  def person_market_kind
    if @person.has_active_consumer_role?
      "individual"
    elsif @person.has_active_employee_role?
      "shop"
    end
  end

  def check_general_agency_profile_permissions_assign
    @broker_agency_profile = BrokerAgencyProfile.find(params[:id])
    policy = ::AccessPolicies::GeneralAgencyProfile.new(current_user)
    policy.authorize_assign(self, @broker_agency_profile)
  end

  def check_general_agency_profile_permissions_set_default
    @broker_agency_profile = BrokerAgencyProfile.find(params[:id])
    policy = ::AccessPolicies::GeneralAgencyProfile.new(current_user)
    policy.authorize_set_default_ga(self, @broker_agency_profile)
  end

  def update_broker_phone(office_location, person)
    phone = office_location.phone
    broker_main_phone = person.phones.where(kind: "work").first
    if broker_main_phone.present?
      broker_main_phone.update_attributes!(
        kind: phone.kind,
        country_code: phone.country_code,
        area_code: phone.area_code,
        number: phone.number,
        extension: phone.extension,
        full_phone_number: phone.full_phone_number
      )
    end
    person.save!
  end
end
