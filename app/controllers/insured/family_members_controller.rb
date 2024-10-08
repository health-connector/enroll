class Insured::FamilyMembersController < ApplicationController
  include VlpDoc
  include ApplicationHelper

  before_action :set_current_person, :set_family
  before_action :set_dependent, only: [:destroy, :show, :edit, :update]

  def index
    set_family_for_index
    authorize @family, :index?

    set_bookmark_url
    @type = (params[:employee_role_id].present? && params[:employee_role_id] != 'None') ? "employee" : "consumer"

    if (params[:resident_role_id].present? && params[:resident_role_id])
      @type = "resident"
      @resident_role = ResidentRole.find(params[:resident_role_id])
      begin
        @family.hire_broker_agency(current_user.person.broker_role.try(:id))
      rescue StandardError => e
        exception_message = "Error: #{e}"
        exception_message += "Unable to find family for person #{@person&.hbx_id}." if @family.blank?
        Rails.logger.error(exception_message) unless Rails.env.test?
        redirect_to root_path and return
      end
      redirect_to resident_index_insured_family_members_path(:resident_role_id => @person.resident_role.id, :change_plan => params[:change_plan], :qle_date => params[:qle_date], :qle_id => params[:qle_id], :effective_on_kind => params[:effective_on_kind], :qle_reason_choice => params[:qle_reason_choice], :commit => params[:commit])
    end

    if @type == "employee"
      emp_role_id = params.require(:employee_role_id)
      @employee_role = @person.employee_roles.detect { |emp_role| emp_role.id.to_s == emp_role_id.to_s }
    elsif @type == "consumer"
      @consumer_role = @person.consumer_role
      @family.hire_broker_agency(current_user.person.broker_role.try(:id))
    end
    @change_plan = params[:change_plan].present? ? 'change_by_qle' : ''
    @change_plan_date = params[:qle_date].present? ? params[:qle_date] : ''

    if params[:sep_id].present?
      @sep = @family.special_enrollment_periods.find(params[:sep_id])
      if @sep.submitted_at.to_date != TimeKeeper.date_of_record
        @sep = duplicate_sep(@sep)
      end
      @qle = QualifyingLifeEventKind.find(params[:qle_id])
      @change_plan = 'change_by_qle'
      @change_plan_date = @sep.qle_on
    elsif params[:qle_id].present? && !params[:shop_for_plan]

      qle = QualifyingLifeEventKind.find(params[:qle_id])
      special_enrollment_period = @family.special_enrollment_periods.new(effective_on_kind: params[:effective_on_kind])
      special_enrollment_period.selected_effective_on = Date.strptime(params[:effective_on_date], "%m/%d/%Y") if params[:effective_on_date].present?
      special_enrollment_period.qualifying_life_event_kind = qle
      special_enrollment_period.qle_on = Date.strptime(params[:qle_date], "%m/%d/%Y")
      special_enrollment_period.qle_answer = params[:qle_reason_choice] if params[:qle_reason_choice].present?
      special_enrollment_period.save
      @market_kind = qle.market_kind
    end

    if request.referer.present?
      @prev_url_include_intractive_identity = request.referer.include?("interactive_identity_verifications")
      @prev_url_include_consumer_role_id = request.referer.include?("consumer_role_id")
    else
      @prev_url_include_intractive_identity = false
      @prev_url_include_consumer_role_id = false
    end

  end

  def new
    family_id = params.require(:family_id)
    @family = Family.find(family_id) if family_id
    authorize @family, :new?

    @dependent = Forms::FamilyMember.new(:family_id => params.require(:family_id))
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    authorize @family, :create?

    @dependent = ::Forms::FamilyMember.new(params[:dependent])

    if ((Family.find(@dependent.family_id)).primary_applicant.person.resident_role?)
      if @dependent.save
        @created = true
        respond_to do |format|
          format.html { render 'show_resident' }
          format.js { render 'show_resident' }
        end
      end
      return
    end

    if @dependent.save && update_vlp_documents(@dependent.family_member.try(:person).try(:consumer_role), 'dependent', @dependent)
      @banner_text = "#{t('insured.family_member_added')} <div class='mt-1'><a href='/insured/families/find_sep' style='text-decoration: underline;'>#{t('insured.shop_with_sep')}</a></div>".html_safe
      if @family.present?
        active_family_members_count = @family.active_family_members&.count
        household = @family.active_household
        immediate_household_members_count = household.immediate_family_coverage_household.coverage_household_members.count
        extended_family_members_count = household.extended_family_coverage_household.coverage_household_members.count
        Rails.logger.info("In FamilyMembersController Create action #{params}, #{@family.inspect}") unless active_family_members_count == immediate_household_members_count + extended_family_members_count
      end
      @created = true
      respond_to do |format|
        format.html { render 'show' }
        format.js { render 'show' }
      end
    else
      @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@dependent.family_member.try(:person).try(:consumer_role))
      init_address_for_dependent
      respond_to do |format|
        format.html { render 'new' }
        format.js { render 'new' }
      end
    end
  end

  def destroy
    authorize @family, :destroy?

    @dependent.destroy!
    @banner_text = "#{t('insured.family_member_removed')} <div class='mt-1'><a href='/insured/families/find_sep' style='text-decoration: underline;'>#{t('insured.shop_with_sep')}</a></div>".html_safe
    if @family.present?
      active_family_members_count = @family.active_family_members&.count
      household = @family.active_household
      immediate_household_members_count = household.immediate_family_coverage_household.coverage_household_members.count
      extended_family_members_count = household.extended_family_coverage_household.coverage_household_members.count
      Rails.logger.info("In FamilyMembersController Destroy action #{params}, #{@family.inspect}") unless active_family_members_count == immediate_household_members_count + extended_family_members_count
    end
    respond_to do |format|
      format.html { render 'index' }
      format.js { render 'destroyed' }
    end
  end

  def show
    authorize @family, :show?

    respond_to do |format|
      format.html
      format.js
    end
  end

  def edit
    authorize @family, :edit?

    consumer_role = @dependent.family_member.try(:person).try(:consumer_role)
    @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(consumer_role) if consumer_role.present?

    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    authorize @family, :update?
    if ((Family.find(@dependent.family_id)).primary_applicant.person.resident_role?)
      if @dependent.update_attributes(params.require(:dependent))
        respond_to do |format|
          format.html { render 'show_resident' }
          format.js { render 'show_resident' }
        end
      end
      return
    end
    consumer_role = @dependent.family_member.try(:person).try(:consumer_role)
    consumer_role.check_for_critical_changes(params[:dependent], @family) if consumer_role
    if @dependent.update_attributes(params.require(:dependent)) && update_vlp_documents(consumer_role, 'dependent', @dependent)
      if @family.present?
        active_family_members_count = @family.active_family_members.count
        household = @family.active_household
        immediate_household_members_count = household.immediate_family_coverage_household.coverage_household_members.count
        extended_family_members_count = household.extended_family_coverage_household.coverage_household_members.count
        Rails.logger.info("In FamilyMembersController Update action #{params}, #{@family.inspect}") unless active_family_members_count == immediate_household_members_count + extended_family_members_count
      end
      consumer_role.update_attribute(:is_applying_coverage,  params[:dependent][:is_applying_coverage]) if consumer_role.present?
      respond_to do |format|
        format.html { render 'show' }
        format.js { render 'show' }
      end
    else
      @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(consumer_role) if consumer_role.present?
      init_address_for_dependent
      respond_to do |format|
        format.html { render 'edit' }
        format.js { render 'edit' }
      end
    end
  end

private
  def set_family
    @family = @person.try(:primary_family)
  end

  def init_address_for_dependent
    if @dependent.same_with_primary == "true"
      @dependent.addresses = [Address.new(kind: 'home'), Address.new(kind: 'mailing')]
    elsif @dependent.addresses.is_a? ActionController::Parameters
      addresses = []
      @dependent.addresses.each do |k, address|
        addresses << Address.new(address.permit!)
      end
      @dependent.addresses = addresses
    end
  end

  def duplicate_sep(sep)
    sp = SpecialEnrollmentPeriod.new(sep.attributes.except("effective_on", "submitted_at", "_id"))
    sp.qualifying_life_event_kind = sep.qualifying_life_event_kind    # initiate sep dates
    @family.special_enrollment_periods << sp
    sp.save
    sp
  end

  def set_family_for_index
    if params[:employee_role_id].present? && params[:employee_role_id] != 'None'
      emp_role_id = params[:employee_role_id]
      @employee_role = if emp_role_id.present?
                         @person.employee_roles.detect { |emp_role| emp_role.id.to_s == emp_role_id.to_s }
                       else
                         @person.employee_roles.detect { |emp_role| emp_role.is_active == true }
                       end
      @family = @person.primary_family
    elsif params[:family_id]
      @family = Family.find(params[:family_id])
    end
  end

  def set_dependent
    @dependent = Forms::FamilyMember.find(params.require(:id))
    @family = Family.find(@dependent.family_id) if @dependent.family_id
  end
end
