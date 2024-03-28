class PeopleController < ApplicationController
  include ApplicationHelper
  include ErrorBubble
  include VlpDoc

  before_action :set_requested_record, except: [:index]

  def update
    authorize record, :can_update?
    @person = find_person(params[:id])
    @family = @person.primary_family
    @person.updated_by = current_user.oim_id unless current_user.nil?

    can_update_vlp = @person.has_active_consumer_role? && request.referer.include?("insured/families/personal")
    update_vlp_documents(@person.consumer_role, 'person') if can_update_vlp

    if @person.has_active_consumer_role?
      @person.consumer_role.check_for_critical_changes(person_params, @family)
    end
    respond_to do |format|
      @person.assign_attributes(person_params.except(:is_applying_coverage))

      redirect_path = personal_insured_families_path
      info_flash = "#{t('insured.address_updated')} <div class='mt-1'><a href='/insured/families/find_sep' style='text-decoration: underline;'>#{t('insured.shop_with_sep')}</a></div>".html_safe if @person.home_address.changed?

      update_census_employee(@person)

      if @person.save
        @person.consumer_role.update_attribute(:is_applying_coverage, person_params[:is_applying_coverage]) if @person.consumer_role.present?
        format.html { redirect_to redirect_path, :flash => { :notice => 'Person was successfully updated.', :info => info_flash }  }
        format.json { head :no_content }
      else
        if @person.has_active_consumer_role?
          bubble_consumer_role_errors_by_person(@person)
          @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@person.consumer_role)
        end
        build_nested_models
        person_error_megs = @person.errors.full_messages.join('<br/>') if @person.errors.present?
        format.html { redirect_to redirect_path, alert: "Person update failed. #{person_error_megs}" }
        # format.html { redirect_to edit_insured_employee_path(@person) }
        format.json { render json: @person.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_census_employee(person)
    return unless person.valid?

    Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
  rescue StandardError => e
    Rails.logger.error { "Failed to update census employee record for #{person.full_name}(#{person.hbx_id}) due to #{e.inspect}" }
  end

  private

  def set_requested_record
    @person = find_person(params[:id])
  end

  def record
    @person
  end

  def safe_find(klass, id)
    begin
      klass.find(id)
    rescue
      nil
    end
  end

  def find_person(id)
    safe_find(Person, id)
  end

  def find_organization(id)
    safe_find(Organization, id)
  end

  def find_hbx_enrollment(id)
    safe_find(HbxEnrollment, id)
  end

  def build_nested_models
    ["home","mobile","work","fax"].each do |kind|
       @person.phones.build(kind: kind) if @person.phones.select{|phone| phone.kind == kind}.blank?
    end

    Address::KINDS.each do |kind|
      @person.addresses.build(kind: kind) if @person.addresses.select{|address| address.kind == kind}.blank?
    end

    ["home","work"].each do |kind|
       @person.emails.build(kind: kind) if @person.emails.select{|email| email.kind == kind}.blank?
    end
  end

  def sanitize_person_params
    if person_params["addresses_attributes"].present?
      person_params["addresses_attributes"].each do |key, address|
        if address["city"].blank? && address["zip"].blank? && address["address_1"].blank? && address['state']
          params["person"]["addresses_attributes"].delete("#{key}")
        end
      end
    end

    if person_params["phones_attributes"].present?
      person_params["phones_attributes"].each do |key, phone|
        if phone["full_phone_number"].blank?
          params["person"]["phones_attributes"].delete("#{key}")
        end
      end
    end

    if person_params["emails_attributes"].present?
      person_params["emails_attributes"].each do |key, email|
        if email["address"].blank?
          params["person"]["emails_attributes"].delete("#{key}")
        end
      end
    end
  end

  def person_params
    params.require(:person).permit(*person_parameters_list)
  end

  def person_parameters_list
    [
      { :addresses_attributes => [:kind, :address_1, :address_2, :city, :state, :zip, :id, :_destroy] },
      { :phones_attributes => [:kind, :full_phone_number, :id, :_destroy] },
      { :emails_attributes => [:kind, :address, :id, :_destroy] },
      { :consumer_role_attributes => [:contact_method, :language_preference, :id]},
      { :employee_roles_attributes => [:id, :contact_method, :language_preference]},

      :first_name,
      :middle_name,
      :last_name,
      :name_sfx,
      :gender,
      :us_citizen,
      :is_incarcerated,
      :language_code,
      :is_disabled,
      :race,
      :is_consumer_role,
      :is_resident_role,
      :naturalized_citizen,
      :eligible_immigration_status,
      :indian_tribe_member,
      {:ethnicity => []},
      :tribal_id,
      :no_dc_address,
      :no_dc_address_reason,
      :id,
      :consumer_role,
      :is_applying_coverage
    ]
  end
end
