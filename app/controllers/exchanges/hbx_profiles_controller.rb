# frozen_string_literal: true

class Exchanges::HbxProfilesController < ApplicationController
  include Exchanges::HbxProfilesHelper
  include ::DataTablesAdapter
  include ::DataTablesSearch
  include Pundit::Authorization
  include ::SepAll
  include ::Config::AcaHelper
  include HtmlScrubberUtil
  include StringScrubberUtil

  before_action :check_hbx_staff_role, except: [:configuration, :show, :assister_index, :family_index, :update_cancel_enrollment, :update_terminate_enrollment]
  before_action :set_hbx_profile, only: :edit
  before_action :view_the_configuration_tab?, only: [:set_date]
  before_action :can_submit_time_travel_request?, only: [:set_date]
  before_action :find_hbx_profile, only: [:employer_index, :configuration, :broker_agency_index, :show, :binder_index]
  #before_action :authorize_for, except: [:edit, :update, :destroy, :request_help, :staff_index, :assister_index]
  #before_action :authorize_for_instance, only: [:edit, :update, :destroy]
  before_action :check_csr_or_hbx_staff, only: [:family_index]
  before_action :find_benefit_sponsorship, only: [:oe_extendable_applications, :oe_extended_applications, :edit_open_enrollment, :extend_open_enrollment, :close_extended_open_enrollment, :edit_fein, :update_fein, :force_publish, :edit_force_publish]
  # GET /exchanges/hbx_profiles
  # GET /exchanges/hbx_profiles.json
  layout 'single_column'

  def index
    @organizations = Organization.exists(hbx_profile: true)
    @hbx_profiles = @organizations.map {|o| o.hbx_profile}
  end

  def oe_extendable_applications
    @benefit_applications  = @benefit_sponsorship.oe_extendable_benefit_applications
    @element_to_replace_id = params[:employer_actions_id]
  end

  def oe_extended_applications
    @benefit_applications  = @benefit_sponsorship.oe_extended_applications
    @element_to_replace_id = params[:employer_actions_id]
  end

  def edit_open_enrollment
    @benefit_application = @benefit_sponsorship.benefit_applications.find(params[:id])
  end

  def extend_open_enrollment
    authorize HbxProfile, :can_extend_open_enrollment?
    @benefit_application = @benefit_sponsorship.benefit_applications.find(params[:id])
    open_enrollment_end_date = DateParser.smart_parse(params["open_enrollment_end_date"])
    ::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(@benefit_application).extend_open_enrollment(open_enrollment_end_date)
    redirect_to exchanges_hbx_profiles_root_path, :flash => { :success => "Successfully extended employer(s) open enrollment." }
  end

  def close_extended_open_enrollment
    authorize HbxProfile, :can_extend_open_enrollment?
    @benefit_application = @benefit_sponsorship.benefit_applications.find(params[:id])
    ::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(@benefit_application).end_open_enrollment(TimeKeeper.date_of_record)
    redirect_to exchanges_hbx_profiles_root_path, :flash => { :success => "Successfully closed employer(s) open enrollment." }
  end

  def new_benefit_application
    authorize HbxProfile, :can_create_benefit_application?
    @ba_form = BenefitSponsors::Forms::BenefitApplicationForm.for_new(new_ba_params)
    @element_to_replace_id = params[:employer_actions_id]
  end

  def create_benefit_application
    @ba_form = BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
    authorize @ba_form, :updateable?
    @save_errors = benefit_application_error_messages(@ba_form) unless @ba_form.save
    @element_to_replace_id = params[:employer_actions_id]
  end

  def edit_fein
    @organization = @benefit_sponsorship.organization
    @element_to_replace_id = params[:employer_actions_id]

    respond_to do |format|
      format.js { render "edit_fein" }
    end
  end

  def update_fein
    @organization = @benefit_sponsorship.organization
    @element_to_replace_id = params[:employer_actions_id]
    service_obj = ::BenefitSponsors::BenefitSponsorships::AcaShopBenefitSponsorshipService.new(benefit_sponsorship: @benefit_sponsorship)
    @result,  @errors_on_save = service_obj.update_fein(params['organizations_general_organization']['new_fein'])
    respond_to do |format|
      format.js { render "edit_fein" } if @errors_on_save
      format.js { render "update_fein" }
    end
  end

  def binder_paid
    authorize HbxProfile, :binder_paid?

    return unless params[:ids]

    begin
      ::BenefitSponsors::BenefitSponsorships::AcaShopBenefitSponsorshipService.set_binder_paid(params[:ids])
      flash["notice"] = "Successfully submitted the selected employer(s) for binder paid."
      render json: { status: 200, message: 'Successfully submitted the selected employer(s) for binder paid.' }
    rescue StandardError => e
      Rails.logger.error(e.message)
      render json: { status: 500, message: 'An error occured while submitting employer(s) for binder paid.' }
    end

    # Removed redirect because of Datatables. Send Results to Datatable Status
    #redirect_to exchanges_hbx_profiles_root_path
  end

  def transmit_group_xml
    authorize HbxProfile, :transmit_group_xml?

    HbxProfile.transmit_group_xml(params[:id].split)
    @employer_profile = EmployerProfile.find(params[:id])
    @fein = @employer_profile.fein
    start_on = @employer_profile.show_plan_year.start_on.strftime("%Y%m%d")
    end_on = @employer_profile.show_plan_year.end_on.strftime("%Y%m%d")
    @xml_submit_time = @employer_profile.xml_transmitted_timestamp
    v2_xml_generator = V2GroupXmlGenerator.new([@fein], start_on, end_on)
    send_data v2_xml_generator.generate_xmls
  end

  def employer_index
    @q = params.permit(:q)[:q]
    @orgs = Organization.search(@q).exists(employer_profile: true)
    @page_alphabets = page_alphabets(@orgs, "legal_name")
    page_no = cur_page_no(@page_alphabets.first)
    @organizations = @orgs.where("legal_name" => /^#{Regexp.escape(page_no)}/i) if page_no.present?

    @employer_profiles = @organizations.map {|o| o.employer_profile}

    respond_to do |format|
      format.html { render "employers/employer_profiles/index" }
      format.js {}
    end
  end

  def generate_invoice
    @benefit_sponsorships = ::BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:_id.in => params[:ids])
    @organizations = @benefit_sponsorships.map(&:organization)
    @employer_profiles = @organizations.flat_map(&:employer_profile)
    @employer_profiles.each do |employer_profile|
      employer_profile.trigger_model_event(:generate_initial_employer_invoice)
    end

    flash["notice"] = "Successfully submitted the selected employer(s) for invoice generation."
    #redirect_to exchanges_hbx_profiles_root_path

    respond_to do |format|
      format.js
    end
  end

  def edit_force_publish
    @element_to_replace_id = params[:employer_actions_id]
    @benefit_application = @benefit_sponsorship.benefit_applications.draft_state.last

    respond_to do |format|
      format.js
    end
  end

  def force_publish
    @element_to_replace_id = params[:employer_actions_id]
    @benefit_application   = @benefit_sponsorship.benefit_applications.draft_state.last
    if @benefit_application.present?
      @service = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(@benefit_application)
      @service.force_submit_application if @service.may_force_submit_application? || params[:publish_with_warnings] == 'true'
    end

    respond_to do |format|
      format.js
    end
  end

  def employer_invoice
    # Dynamic Filter values for upcoming 30, 60, 90 days renewals
    @next_30_day = TimeKeeper.date_of_record.next_month.beginning_of_month
    @next_60_day = @next_30_day.next_month
    @next_90_day = @next_60_day.next_month

    @datatable = Effective::Datatables::BenefitSponsorsEmployerDatatable.new

    respond_to do |format|
      format.js
    end
  end

  def employer_datatable
    # copy the link and open in new tab
    last_visited_url = current_user.try(:last_portal_visited) || root_path if current_user.present?
    @datatable = Effective::Datatables::BenefitSponsorsEmployerDatatable.new
    respond_to do |format|
      format.html { redirect_to(last_visited_url, allow_other_host: true) }
      format.js
    end
  end

  def staff_index
    @q = params.permit(:q)[:q]
    @staff = Person.where(:$or => [{csr_role: {:$exists => true}}, {assister_role: {:$exists => true}}])
    @page_alphabets = page_alphabets(@staff, "last_name")
    page_no = cur_page_no(@page_alphabets.first)
    @staff = if @q.nil?
               page_no.present? ? @staff.where(last_name: /^#{Regexp.escape(page_no)}/i) : []
             else
               @staff.where(last_name: @q)
             end
  end

  def assister_index
    authorize HbxProfile, :assister_index?

    @q = params.permit(:q)[:q]
    @staff = Person.where(assister_role: {:$exists => true})
    @page_alphabets = page_alphabets(@staff, "last_name")
    page_no = cur_page_no(@page_alphabets.first)
    @staff = if @q.nil?
               @staff.where(last_name: /^#{Regexp.escape(page_no)}/i)
             else
               @staff.where(last_name: @q)
             end
  end

  def family_index
    authorize HbxProfile, :family_index?

    @q = params.permit(:q)[:q]
    page_string = params.permit(:families_page)[:families_page]
    page_no = page_string.blank? ? nil : page_string.to_i
    if @q.present?
      total_families = Person.search(@q).map(&:families).flatten.uniq
      @total = total_families.count
      @families = Kaminari.paginate_array(total_families).page page_no
    else
      @families = Family.page page_no
      @total = Family.count
    end
    respond_to do |format|
      format.html { render "insured/families/index" }
      format.js
    end
  end

  def family_index_dt
    @selector = params[:scopes][:selector] if params[:scopes].present?
    @datatable = Effective::Datatables::FamilyDataTable.new(params[:scopes])
    #render '/exchanges/hbx_profiles/family_index_datatable'
  end

  def user_account_index
    authorize HbxProfile, :can_access_user_account_tab?
    @datatable = Effective::Datatables::UserAccountDatatable.new
    respond_to do |format|
      format.js
      format.html { render '/exchanges/hbx_profiles/user_account_index_datatable' }
    end
  end

  def outstanding_verification_dt
    @selector = params[:scopes][:selector] if params[:scopes].present?
    @datatable = Effective::Datatables::OutstandingVerificationDataTable.new(params[:scopes])
  end

  def hide_form
    @element_to_replace_id = params[:family_actions_id]
  end

  def add_sep_form
    authorize HbxProfile, :can_add_sep?
    getActionParams
    @element_to_replace_id = params[:family_actions_id]
  end

  def show_sep_history
    getActionParams
    @element_to_replace_id = params[:family_actions_id]
  end

  def get_user_info
    @element_to_replace_id = params[:family_actions_id] || params[:employers_action_id]
    if params[:person_id].present?
      @person = Person.find(params[:person_id])
    else
      @employer_actions = true
      @people = Person.where(:id => { "$in" => (params[:people_id] || []) })
      @organization = if params.key?(:employers_action_id)
                        EmployerProfile.find(@element_to_replace_id.split("_").last).organization
                      else
                        Organization.find(@element_to_replace_id.split("_").last)
                      end
    end
  end

  def update_effective_date
    @qle = QualifyingLifeEventKind.find(params[:id])
    respond_to do |format|
      format.js {}
    end
    calculate_rule
  end

  def calculate_sep_dates
    calculateDates
    respond_to do |format|
      format.js {}
    end
  end

  def add_new_sep
    return unless params[:qle_id].present?

    @element_to_replace_id = params[:family_actions_id]
    createSep
    respond_to do |format|
      format.js { render "sep/approval/add_sep_result.js.erb", name: @name }
    end
  end

  def cancel_enrollment
    @hbxs = Family.find(params[:family]).all_enrollments.cancel_eligible
    @row = params[:family_actions_id]
    respond_to do |format|
      format.js { render "datatables/cancel_enrollment" }
    end
  end

  def update_cancel_enrollment
    authorize HbxProfile, :update_cancel_enrollment?

    params_parser = ::Forms::BulkActionsForAdmin.new(params.permit(uniq_cancel_params).to_h)
    @result = params_parser.result
    @row = params_parser.row
    @family_id = params_parser.family_id
    params_parser.cancel_enrollments
    respond_to do |format|
      format.js { render "datatables/cancel_enrollment_result.js.erb"}
    end
  end

  def terminate_enrollment
    @hbxs = Family.find(params[:family]).all_enrollments.can_terminate
    @row = params[:family_actions_id]
    respond_to do |format|
      format.js { render "datatables/terminate_enrollment" }
    end
  end

  def update_terminate_enrollment
    authorize HbxProfile, :update_terminate_enrollment?

    params_parser = ::Forms::BulkActionsForAdmin.new(params.permit(uniq_terminate_params).to_h)
    @result = params_parser.result
    @row = params_parser.row
    @family_id = params_parser.family_id
    params_parser.terminate_enrollments
    respond_to do |format|
      format.js { render "datatables/terminate_enrollment_result.js.erb"}
    end
  end

  def view_enrollment_to_update_end_date
    @person = Person.find(params[:person_id])
    @row = params[:family_actions_id]
    @enrollments = @person.primary_family.terminated_enrollments
    @coverage_ended_enrollments = @person.primary_family.enrollments.where(:aasm_state.in => ["coverage_terminated", "coverage_termination_pending", "coverage_expired"])
    @dup_enr_ids = fetch_duplicate_enrollment_ids(@coverage_ended_enrollments).map(&:to_s)
  end

  def update_enrollment_termianted_on_date
    begin
      enrollment = HbxEnrollment.find(params[:enrollment_id])
      @row = params[:family_actions_id]
      termination_date = DateParser.smart_parse(params["new_termination_date"])
      message = if enrollment.present? && enrollment.reterm_enrollment_with_earlier_date(termination_date, params["edi_required"].present?)
                  {notice: "Enrollment Updated Successfully."}
                else
                  {notice: "Unable to find/update Enrollment."}
                end
    rescue Exception => e
      message = {error: e.to_s}
    end
    redirect_to exchanges_hbx_profiles_root_path, flash: message
  end

  def broker_agency_index
    @datatable = Effective::Datatables::BrokerAgencyDatatable.new

    #@q = params.permit(:q)[:q]
    #@broker_agency_profiles = HbxProfile.search_random(@q)


    respond_to do |format|
      format.js {}
    end
  end

  def general_agency_index
    page_string = params.permit(:gas_page)[:gas_page]
    page_no = page_string.blank? ? nil : page_string.to_i

    status_params = params.permit(:status)
    @status = status_params[:status] || 'is_applicant'
    @general_agency_profiles = GeneralAgencyProfile.filter_by(@status)
    @general_agency_profiles = Kaminari.paginate_array(@general_agency_profiles).page(page_no)

    respond_to do |format|
      format.html { render 'general_agency' }
      format.js
    end
  end

  def issuer_index
    authorize HbxProfile, :view_admin_tabs?
    @marketplaces = [{
      name: l10n("marketplaces.shop_type"),
      plans_number: BenefitMarkets::Products::Product.count,
      enrollments_number: Family.actual_enrollments_number,
      products: BenefitMarkets::Products::Product
        .distinct(:kind)
        .map { |kind| kind.to_s.capitalize }
        .sort
        .reverse
        .join(", ")
    }]

    respond_to do |format|
      format.html { render "issuer_index", layout: 'exchanges_base' }
      format.js
    end
  end

  def marketplace_plan_year
    authorize HbxProfile, :view_admin_tabs?
    year = params[:year].to_i
    all_carriers = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map do |org|
      {
        legal_name: org[:legal_name],
        organization_id: org._id,
        profile_ids: org.profiles.map(&:_id)
      }
    end

    @carriers = fetch_carriers_data(all_carriers, year)

    respond_to do |format|
      format.html { render "marketplace_plan_year", layout: 'exchanges_base' }
      format.js
    end
  end

  def marketplace_plan_years
    authorize HbxProfile, :view_admin_tabs?

    @years_data = fetch_products_data_by_years

    respond_to do |format|
      format.html { render "marketplace_plan_years", layout: 'exchanges_base' }
      format.js
    end
  end

  def carrier
    authorize HbxProfile, :view_admin_tabs?
    year = params[:year].to_i
    @carrier = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.find(params[:id])
    products = BenefitMarkets::Products::Product.where(
      :"application_period.min".lte => Date.new(year, 12, 31),
      :"application_period.max".gte => Date.new(year, 1, 1),
      :issuer_profile_id.in => @carrier.profiles.map(&:_id)
    )

    @products_data = products.map { |product| product_data(product) }
    products_types = products.map(&:plan_types).flatten.uniq
    @filter_options = {
      plan_types: BenefitMarkets::Products::Product.types.slice(*products_types),
      rating_areas: pvp_rating_area_options(products),
      metal_levels: products.map { |p| [p.metal_level, p.metal_level.to_s.capitalize] }.uniq.to_h
    }

    respond_to do |format|
      format.html { render "carrier", layout: 'exchanges_base' }
      format.js
    end
  end

  def plan_details
    authorize HbxProfile, :view_admin_tabs?
    @product = BenefitMarkets::Products::Product.find(params[:product_id])
    @qhp = Products::QhpCostShareVariance.find_qhp_cost_share_variances([@product.hios_id], params[:year], @product.kind.to_s).first
    @rating_areas = BenefitMarkets::Locations::RatingArea.by_year(@product.active_year).pluck(:exchange_provided_code, :id).uniq.sort.to_h
    @product_rating_areas = @product.premium_tables.map(&:rating_area).pluck(:exchange_provided_code, :id).uniq.to_h
    @product_pvp_eligible_ras = fetch_eligible_pvp_ras_for(@product)

    respond_to do |format|
      format.html { render "plan_details", layout: 'exchanges_base' }
      format.js
    end
  end

  def mark_pvp_eligibilities
    authorize HbxProfile, :can_mark_pvp_eligibilities?

    permitted_params = params.permit(:product_id, :pvp_active_areas => {})
    @product = BenefitMarkets::Products::Product.find(permitted_params[:product_id])
    args = {rating_areas: permitted_params[:pvp_active_areas].to_h}
    service = BenefitMarkets::Services::PvpEligibilityService.new(@product, current_user, args)
    result = service.create_or_update_pvp_eligibilities

    message = if result["Failure"].present?
                { failure: l10n('hbx_profiles.mark_pvp_failure') }
              else
                { success: l10n('hbx_profiles.mark_pvp_success') }
              end

    redirect_to plan_details_exchanges_hbx_profiles_path(
      year: @product.active_year,
      id: @product.issuer_profile.organization.id,
      product_id: @product.id,
      market: @product.benefit_market_kind.to_s.split('_').last
    ), flash: message
  end

  def verification_index
    #@families = Family.by_enrollment_individual_market.where(:'households.hbx_enrollments.aasm_state' => "enrolled_contingent").page(params[:page]).per(15)
    # @datatable = Effective::Datatables::DocumentDatatable.new
    @documents = [] # Organization.all_employer_profiles.employer_profiles_with_attestation_document

    respond_to do |format|
      format.html { render partial: "index_verification" }
      format.js {}
    end
  end

  def binder_index
    @organizations = Organization.retrieve_employers_eligible_for_binder_paid

    respond_to do |format|
      format.html { render "employers/employer_profiles/binder_index" }
      format.js {}
    end
  end

  def binder_index_datatable
    dt_query = extract_datatable_parameters
    organizations = []

    all_organizations = Organization.retrieve_employers_eligible_for_binder_paid

    organizations = if dt_query.search_string.blank?
                      all_organizations
                    else
                      org_ids = Organization.search(dt_query.search_string).pluck(:id)
                      all_organizations.where({
                                                "id" => {"$in" => org_ids}
                                              })
                    end

    @draw = dt_query.draw
    @total_records = all_organizations.count
    @records_filtered = organizations.count
    @organizations = organizations.skip(dt_query.skip).limit(dt_query.take)
    render
  end

  def product_index
    respond_to do |format|
      format.html { render "product_index" }
      format.js {}
    end
  end

  def configuration
    authorize HbxProfile, :configuration?

    @time_keeper = Forms::TimeKeeper.new
    respond_to do |format|
      format.html { render partial: "configuration_index" }
      format.js {}
    end
  end

  def view_terminated_hbx_enrollments
    @person = Person.find(params[:person_id])
    @element_to_replace_id = params[:family_actions_id]
    @enrollments = @person.primary_family.terminated_enrollments
  end

  def reinstate_enrollment
    enrollment = HbxEnrollment.find(params[:enrollment_id])
    if enrollment.present?
      begin
        reinstated_enrollment = enrollment.reinstate(edi: params['edi_required'].present?)
        if reinstated_enrollment.present?
          reinstated_enrollment.comments.create(:content => params[:comments], :user => current_user.id) if params['comments'].present?
          message = {notice: "Enrollment Reinstated successfully."}
        end
      rescue Exception => e
        message = {error: e.to_s}
      end
    else
      message = {notice: "Unable to find Enrollment."}
    end

    redirect_to exchanges_hbx_profiles_root_path, flash: message
  end

  def edit_dob_ssn
    authorize Family, :can_update_ssn?
    @person = Person.find(params[:id])
    @element_to_replace_id = params[:family_actions_id]
    respond_to do |format|
      format.js { render "edit_enrollment", person: @person, person_has_active_enrollment: @person_has_active_enrollment}
    end
  end

  def verify_dob_change
    @person = Person.find(params[:person_id])
    @element_to_replace_id = params[:family_actions_id]
    @premium_implications = Person.dob_change_implication_on_active_enrollments(@person, params[:new_dob])
    respond_to do |format|
      format.js { render "edit_enrollment", person: @person, :new_ssn => params[:new_ssn], :new_dob => params[:new_dob],  :family_actions_id => params[:family_actions_id]}
    end
  end

  def update_dob_ssn
    authorize Family, :can_update_ssn?
    @element_to_replace_id = params[:person][:family_actions_id]
    @person = Person.find(params[:person][:pid]) if !params[:person].blank? && !params[:person][:pid].blank?
    @ssn_match = Person.find_by_ssn(params[:person][:ssn]) unless params[:person][:ssn].blank?

    if !@ssn_match.blank? && (@ssn_match.id != @person.id) # If there is a SSN match with another person.
      @dont_allow_change = true
    else
      begin
        @person.update_attributes!(dob: Date.strptime(params[:jq_datepicker_ignore_person][:dob], '%m/%d/%Y').to_date, encrypted_ssn: Person.encrypt_ssn(params[:person][:ssn]))
        CensusEmployee.update_census_employee_records(@person, current_user)
      rescue Exception => e
        @error_on_save = @person.errors.messages
        @error_on_save[:census_employee] = [e.summary] if @person.errors.messages.blank? && e.present?
      end
    end
    respond_to do |format|
      format.js { render "edit_enrollment", person: @person, :family_actions_id => params[:person][:family_actions_id]  } if @error_on_save
      format.js { render "update_enrollment", person: @person, :family_actions_id => params[:person][:family_actions_id] }
    end
  end

  # GET /exchanges/hbx_profiles/1
  # GET /exchanges/hbx_profiles/1.json
  def show
    if current_user.has_csr_role? || current_user.try(:has_assister_role?)
      redirect_to home_exchanges_agents_path
      return
    else
      unless current_user.has_hbx_staff_role?
        redirect_to root_path, :flash => { :error => "You must be an HBX staff member" }
        return
      end
    end

    authorize HbxProfile, :show?

    session[:person_id] = nil
    session[:dismiss_announcements] = nil
    @unread_messages = @profile.inbox.unread_messages.try(:count) || 0
  end

  # GET /exchanges/hbx_profiles/new
  def new
    @organization = Organization.new
    @hbx_profile = @organization.build_hbx_profile
  end

  # GET /exchanges/hbx_profiles/1/edit
  def edit; end

# FIXME: I have removed all writes to the HBX Profile models as we
#        don't seem to have functionality that requires them nor
#        permission checks around them.

  # GET /exchanges/hbx_profiles/1/inbox
#  def inbox
#    @inbox_provider = current_user.person.hbx_staff_role.hbx_profile
#    @folder = params[:folder] || 'inbox'
#    @sent_box = true
#  end

  # POST /exchanges/hbx_profiles
  # POST /exchanges/hbx_profiles.json
#  def create
#    @organization = Organization.new(organization_params)
#    @hbx_profile = @organization.build_hbx_profile(hbx_profile_params.except(:organization))

#    respond_to do |format|
#      if @hbx_profile.save
#        format.html { redirect_to exchanges_hbx_profile_path @hbx_profile, notice: 'HBX Profile was successfully created.' }
#        format.json { render :show, status: :created, location: @hbx_profile }
#      else
#        format.html { render :new }
#        format.json { render json: @hbx_profile.errors, status: :unprocessable_entity }
#      end
#    end
#  end

  # PATCH/PUT /exchanges/hbx_profiles/1
  # PATCH/PUT /exchanges/hbx_profiles/1.json
#  def update
#    respond_to do |format|
#      if @hbx_profile.update(hbx_profile_params)
#        format.html { redirect_to exchanges_hbx_profile_path @hbx_profile, notice: 'HBX Profile was successfully updated.' }
#        format.json { render :show, status: :ok, location: @hbx_profile }
#      else
#        format.html { render :edit }
#        format.json { render json: @hbx_profile.errors, status: :unprocessable_entity }
#      end
#    end
#  end

  # DELETE /exchanges/hbx_profiles/1
  # DELETE /exchanges/hbx_profiles/1.json
#  def destroy
#    @hbx_profile.destroy
#    respond_to do |format|
#      format.html { redirect_to exchanges_hbx_profiles_path, notice: 'HBX Profile was successfully destroyed.' }
#      format.json { head :no_content }
#    end
#  end

  def set_date
    authorize HbxProfile, :modify_admin_tabs?
    forms_time_keeper = Forms::TimeKeeper.new(timekeeper_params.to_h)
    begin
      forms_time_keeper.set_date_of_record(forms_time_keeper.forms_date_of_record)
      flash[:notice] = "Date of record set to " + TimeKeeper.date_of_record.strftime("%m/%d/%Y")
    rescue StandardError => e
      flash[:error] = "Failed to set date of record, " + e.message
    end
    redirect_to exchanges_hbx_profiles_root_path
  end

  # Enrollments for APTC / CSR
  def aptc_csr_family_index
    raise NotAuthorizedError unless current_user.has_hbx_staff_role?

    @q = params.permit(:q)[:q]
    page_string = params.permit(:families_page)[:families_page]
    page_no = page_string.blank? ? nil : page_string.to_i
    if @q.present?
      person_ids = Person.search(@q).map(&:_id)

      total_families = Family.all_active_assistance_receiving_for_current_year.in("family_members.person_id" => person_ids).entries
      @total = total_families.count
      @families = Kaminari.paginate_array(total_families).page page_no
    else
      @families = Family.all_active_assistance_receiving_for_current_year.page page_no
      @total = Family.all_active_assistance_receiving_for_current_year.count
    end
    respond_to do |format|
      #format.html { render "insured/families/aptc_csr_listing" }
      format.js {}
    end
  end

  def update_setting
    authorize HbxProfile, :modify_admin_tabs?
    setting_record = Setting.where(name: setting_params[:name]).last

    begin
      setting_record.update(value: setting_params[:value]) if setting_record.present?
    rescue StandardError => e
      flash[:error] = "Failed to update setting, " + e.message
    end
    redirect_to exchanges_hbx_profiles_root_path
  end

  private

  def pvp_rating_area_options(products)
    eligible_pvp_ras = products.map do |product|
      fetch_eligible_pvp_ras_for(product)
    end
    eligible_pvp_ras.reduce({}) { |acc, hash| acc.merge(hash) }.sort
  end

  def fetch_products_data_by_years
    product_ids_by_year = BenefitMarkets::Products::Product.pluck(:application_period, :id).each_with_object({ }) do |data, result|
      (result[data[0].min.year] ||= []) << data[1]
    end.sort.reverse.to_h

    all_product_ids = BenefitMarkets::Products::Product.pluck(:id)
    enrollments_data = Family.actual_enrollment_counts_by_products(all_product_ids)
    enrollments_by_product = enrollments_data.index_by { |data| data["_id"] }

    product_ids_by_year.map do |year, product_ids|
      enrollments_count = product_ids.sum { |p_id| enrollments_by_product[p_id]&.dig("enrollment_count") || 0 }
      products_query = BenefitMarkets::Products::Product.where(:id.in => product_ids)
      {
        year: year,
        plans_number: product_ids.count,
        pvp_numbers: eligible_pvps(product_ids).count,
        enrollments_number: enrollments_count,
        product_kinds: format_product_kinds(products_query.distinct(:kind))
      }
    end
  end

  def format_product_kinds(kinds)
    kinds.uniq.map { |kind| kind.to_s.capitalize }.sort.reverse.join(", ")
  end

  def fetch_all_carriers_product_for(carriers, year)
    all_profile_ids = carriers.flat_map { |carrier| carrier[:profile_ids] }
    BenefitMarkets::Products::Product.where(
      :"application_period.min".lte => Date.new(year, 12, 31),
      :"application_period.max".gte => Date.new(year, 1, 1),
      :issuer_profile_id.in => all_profile_ids
    )
  end

  def products_data_by_carrier(carrier, products, enrollments_count)
    {
      carrier: carrier[:legal_name],
      organization_id: carrier[:organization_id],
      plans_number: products.count,
      enrollments_number: enrollments_count,
      pvp_numbers: eligible_pvps(products.map(&:_id)).count,
      product_kinds: format_product_kinds(products.map(&:kind))
    }
  end

  def fetch_carriers_data(carriers, year)
    product_query = fetch_all_carriers_product_for(carriers, year)
    products_by_carrier = product_query.group_by(&:issuer_profile_id)
    all_product_ids = product_query.pluck(:_id)
    enrollments_data = Family.actual_enrollment_counts_by_products(all_product_ids)

    enrollments_by_product = enrollments_data.index_by { |data| data["_id"] }

    carriers.map do |carrier|
      profile_ids = carrier[:profile_ids]
      carrier_products = profile_ids.flat_map { |profile_id| products_by_carrier[profile_id] || [] }
      product_ids = carrier_products.map(&:_id)
      next if product_ids.empty?

      enrollments_count = product_ids.sum { |p_id| enrollments_by_product[p_id]&.dig("enrollment_count") || 0 }
      products_data_by_carrier(carrier, carrier_products, enrollments_count)
    end.compact
  end

  def product_data(product)
    {
      product_id: product.id,
      plan_name: product.title,
      plan_type: capitalize_value(product.plan_types).join(', '),
      pvp_areas: fetch_eligible_pvp_ras_for(product),
      plan_id: product.hios_id,
      metal_level_kind: product.metal_level.to_s.capitalize
    }
  end

  def capitalize_value(symbols)
    symbols.map { |s| s.to_s.length <= 3 ? s.to_s.upcase : s.to_s.capitalize }
  end

  def fetch_eligible_pvp_ras_for(product)
    product.premium_value_products.select { |pvp| pvp.latest_active_pvp_eligibility_on.present? }
           .map { |pvp| [pvp.rating_area.exchange_provided_code, pvp.rating_area.id] }.uniq.to_h
  end

  def eligible_pvps(product_ids)
    BenefitMarkets::Products::PremiumValueProduct.where(
      :product_id.in => product_ids,
      :eligibilities => {:$elemMatch => {key: :cca_shop_pvp_eligibility, current_state: :eligible}}
    )
  end

  def uniq_terminate_params
    params.keys.map { |key| key.match(/terminate_hbx_.*/) || key.match(/termination_date_.*/) || key.match(/transmit_hbx_.*/) || key.match(/family_.*/) }.compact.map(&:to_s)
  end

  def timekeeper_params
    params.require(:forms_time_keeper).permit(:date_of_record)
  end

  def uniq_cancel_params
    params.keys.map { |key| key.match(/cancel_hbx_.*/) || key.match(/cancel_date_.*/) || key.match(/transmit_hbx_.*/) || key.match(/family_.*/) }.compact.map(&:to_s)
  end

  def group_enrollments_by_year_and_market(all_enrollments)
    current_year = TimeKeeper.date_of_record.year
    years = (2015..(current_year + 1))

    years.inject({}) do |hash_map, year|
      ivl_enrs = all_enrollments.select{ |enrollment| !enrollment.is_shop? && enrollment.effective_on.year == year }
      shop_enrs = all_enrollments.select do |enrollment|
        next unless enrollment.present? || enrollment.sponsored_benefit_package.present?

        enrollment.is_shop? && enrollment.sponsored_benefit_package.start_on.year == year
      end
      hash_map["ivl_#{year}"] = ivl_enrs if ivl_enrs.present?
      hash_map["shop_#{year}"] = shop_enrs if shop_enrs.present?
      hash_map
    end
  end

  def duplicate_enrs_by_market_year(market_enrollments)
    if market_enrollments.first.is_shop?
      market_enrollments.each_cons(2).select do |enr, next_enr|
        (enr.subscriber.applicant_id == next_enr.subscriber.applicant_id) &&
          (enr.market_name == next_enr.market_name) &&
          (enr.product.id == next_enr.product.id) &&
          (enr.benefit_sponsorship_id == next_enr.benefit_sponsorship_id) &&
          (enr.sponsored_benefit_package_id == next_enr.sponsored_benefit_package_id) &&
          (enr.sponsored_benefit_package.start_on == next_enr.sponsored_benefit_package.start_on)
      end
    else
      market_enrollments.each_cons(2).select do |enr, next_enr|
        (enr.subscriber.applicant_id == next_enr.subscriber.applicant_id) &&
          (enr.market_name == next_enr.market_name) &&
          (enr.product.id == next_enr.product.id)
      end
    end
  end

  def get_duplicate_enrs(market_enrollments)
    product_ids = market_enrollments.flatten.map(&:product_id)
    return [] if product_ids.uniq.count == product_ids.count

    dup_enrs = duplicate_enrs_by_market_year(market_enrollments)
    dup_enrs.flatten.compact.count > 1 ? dup_enrs.flatten.compact : []
  end

  def fetch_duplicate_enrollment_ids(enrollments)
    enrs_mapping_by_year_and_market = group_enrollments_by_year_and_market(enrollments)
    return [] if enrs_mapping_by_year_and_market.blank?

    enrs_mapping_by_year_and_market.inject([]) do |duplicate_ids, (_market_year, market_enrollments)|
      next duplicate_ids unless market_enrollments.count > 1

      dups = get_duplicate_enrs(market_enrollments)
      next duplicate_ids if dups.empty?

      effective_date = dups.map(&:effective_on).max
      dups.each do |enr|
        duplicate_ids << enr.id if enr.effective_on < effective_date
      end
      duplicate_ids
    end
  end

  def benefit_application_error_messages(obj)
    obj.errors.full_messages.collect { |error| sanitize_html("<li>#{error}</li>") }
  end

  def new_ba_params
    { benefit_sponsorship_id: sanitize_to_hex(params[:benefit_sponsorship_id]), admin_datatable_action: true }
  end

  def create_ba_params
    params.merge!({ pte_count: '0', msp_count: '0', admin_datatable_action: true })
    params.permit(:start_on, :end_on, :fte_count, :pte_count, :msp_count,
                  :open_enrollment_start_on, :open_enrollment_end_on, :benefit_sponsorship_id, :admin_datatable_action, :has_active_ba)
  end

  def modify_admin_tabs?
    authorize HbxProfile, :modify_admin_tabs?
  end

  def can_submit_time_travel_request?
    return if authorize HbxProfile, :can_submit_time_travel_request?

    redirect_to root_path, :flash => { :error => "Access not allowed" }
  end

  def view_admin_tabs?
    authorize HbxProfile, :view_admin_tabs?
  end

  def setting_params
    params.require(:setting).permit(:name, :value)
  end

  def find_hbx_profile
    @profile = current_user.person.try(:hbx_staff_role).try(:hbx_profile)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_hbx_profile
    @hbx_profile = HbxProfile.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def organization_params
    params[:hbx_profile][:organization].permit(:organization_attributes)
  end

  def hbx_profile_params
    params[:hbx_profile].permit(:hbx_profile_attributes)
  end

  def check_hbx_staff_role
    return if current_user.has_hbx_staff_role?

    redirect_to root_path, :flash => { :error => "You must be an HBX staff member" }
  end

  def view_the_configuration_tab?
    return if authorize HbxProfile, :view_the_configuration_tab?

    redirect_to root_path, :flash => { :error => "Access not allowed" }
  end

  def check_csr_or_hbx_staff
    return if current_user.has_hbx_staff_role? || (current_user.person.csr_role && !current_user.person.csr_role.cac)

    redirect_to root_path, :flash => { :error => "You must be an HBX staff member or a CSR" }
  end

  def authorize_for_instance
    authorize @hbx_profile, "#{action_name}?".to_sym
  end

  def find_benefit_sponsorship
    @benefit_sponsorship = ::BenefitSponsors::BenefitSponsorships::BenefitSponsorship.find(params[:benefit_sponsorship_id] || params[:id])
    raise "Unable to find benefit sponsorship" if @benefit_sponsorship.blank?
  end

end