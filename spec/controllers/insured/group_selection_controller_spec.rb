# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_site_spec_helpers"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_product_spec_helpers"

RSpec.describe Insured::GroupSelectionController, :type => :controller, dbclean: :after_each do
    #include_context "setup benefit market with market catalogs and product packages"

  let(:site) { BenefitSponsors::SiteSpecHelpers.create_cca_site_with_hbx_profile_and_empty_benefit_market }
  let(:benefit_market) { site.benefit_markets.first }
  let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
  let!(:current_benefit_market_catalog) do
    create(
      :benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: benefit_market,
      issuer_profile: issuer_profile,
      title: "SHOP Benefits for #{current_effective_date.year}",
      application_period: current_effective_date.beginning_of_year..current_effective_date.end_of_year
    )
  end
  let(:current_effective_date) { TimeKeeper.date_of_record.end_of_month + 1.day + 1.month }
  include_context "setup initial benefit application"

  let(:rating_area)         { FactoryBot.create_default :benefit_markets_locations_rating_area, active_year: current_effective_date.year }
  let(:service_area)        { FactoryBot.create_default :benefit_markets_locations_service_area, active_year: current_effective_date.year }
  let!(:person) {FactoryBot.create(:person, :with_consumer_role)}
  let!(:family) {FactoryBot.create(:family, :with_primary_family_member, :person => person)}
  let(:qle_kind) { FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date) }
  let!(:sep) do
    sep = family.special_enrollment_periods.new
    sep.effective_on_kind = 'date_of_event'
    sep.qualifying_life_event_kind = qle_kind
    sep.qle_on = TimeKeeper.date_of_record - 7.days
    sep.save
    sep
  end

  let!(:household) {FactoryBot.create(:household, family: family)}
  let!(:user) { FactoryBot.create(:user, :person => person)}
  let!(:coverage_household) {household.add_household_coverage_member(family.primary_family_member)}
  let!(:consumer_role) {person.consumer_role}
  let(:plan_year) {initial_application}
  let(:plan_year_start_on) {TimeKeeper.date_of_record.next_month.end_of_month + 1.day}
  let(:plan_year_end_on) {(plan_year_start_on + 1.month) - 1.day}
  let(:blue_collar_benefit_group) {plan_year.benefit_groups[0]}

  def blue_collar_benefit_group_assignment
    BenefitGroupAssignment.new(benefit_group: blue_collar_benefit_group, start_on: plan_year_start_on)
  end

  let!(:blue_collar_census_employees) do
    ees = FactoryBot.build_list(:census_employee, 1, employer_profile: benefit_sponsorship.profile, benefit_sponsorship: benefit_sponsorship)
    ees.each do |ee|
      ee.benefit_group_assignments = [blue_collar_benefit_group_assignment]
      ee.save
      ee.save!
    end
    ees
  end
  let!(:census_employee) {CensusEmployee.all[0]}

  let!(:employee_role) do
    person.employee_roles.create(employer_profile: abc_profile, census_employee: census_employee,
                                 hired_on: census_employee.hired_on)
  end
  let(:blue_collar_benefit_group) {initial_application.benefit_groups[0]}
  let(:plan_year_start_on) {TimeKeeper.date_of_record.next_month.end_of_month + 1.day}
  let(:plan_year_end_on) {(plan_year_start_on + 1.month) - 1.day}
  let!(:update_plan_year) do
    plan_year.benefit_application_items.create(:effective_period => plan_year_start_on..plan_year_end_on, state: :enrollment_open, sequence_id: 1)
    plan_year.update_attributes!(aasm_state: :enrollment_open)
    plan_year.save!
    plan_year.reload
  end

  let!(:update_person) do
    person.employee_roles.first.census_employee = census_employee
    person.employee_roles.first.hired_on = census_employee.hired_on
    person.employee_roles.first.save
    person.save
  end

  let!(:hbx_enrollment) do
    FactoryBot.create(:hbx_enrollment, household: family.active_household,
                                       sponsored_benefit_package_id: initial_application.benefit_packages.first.id)
  end
  let(:hbx_enrollments) {double(:enrolled => [hbx_enrollment], :where => collectiondouble)}
  let!(:collectiondouble) { double(where: double(order_by: [hbx_enrollment]))}
  let!(:hbx_profile) do
    profile = FactoryBot.create(:hbx_profile)
    profile.benefit_sponsorship.benefit_coverage_periods << FactoryBot.build(:benefit_coverage_period, :next_years_open_enrollment_coverage_period)
    profile
  end
  let(:benefit_group) { FactoryBot.create(:benefit_group)}
  let(:benefit_package) do
    FactoryBot.build(:benefit_package,
                     benefit_coverage_period: hbx_profile.benefit_sponsorship.benefit_coverage_periods.first,
                     title: "individual_health_benefits_2015",
                     elected_premium_credit_strategy: "unassisted",
                     benefit_eligibility_element_group: BenefitEligibilityElementGroup.new(
                       market_places: ["individual"],
                       enrollment_periods: ["open_enrollment", "special_enrollment"],
                       family_relationships: BenefitEligibilityElementGroup::INDIVIDUAL_MARKET_RELATIONSHIP_CATEGORY_KINDS,
                       benefit_categories: ["health"],
                       incarceration_status: ["unincarcerated"],
                       age_range: 0..0,
                       citizenship_status: ["us_citizen", "naturalized_citizen", "alien_lawfully_present", "lawful_permanent_resident"],
                       residency_status: ["state_resident"],
                       ethnicity: ["any"]
                     ))
  end
  let(:bcp) { double }
  let(:sponsored_benefit_package) do
    instance_double(
      ::BenefitSponsors::BenefitPackages::BenefitPackage,
      :id => sponsored_benefit_package_id,
      :recorded_rating_area => double(:id => rating_area_id),
      benefit_sponsorship: double(:id => benefit_sponsorship_id),
      sponsored_benefits: [sponsored_benefit]
    )
  end
  let(:existing_product_id) { BSON::ObjectId.new }
  let(:benefit_sponsorship_id) { BSON::ObjectId.new }
  let(:rating_area_id) { BSON::ObjectId.new }
  let(:sponsored_benefit_package_id) { BSON::ObjectId.new }
  let(:coverage_household_id) { BSON::ObjectId.new }
  let(:sponsored_benefit) { instance_double(::BenefitSponsors::BenefitPackages::BenefitPackage, :id => sponsored_benefit_id) }
  let(:sponsored_benefit_id) { BSON::ObjectId.new }

  before do
    hbx_enrollment.hbx_enrollment_members.build(applicant_id: family.family_members.first.id, is_subscriber: true, coverage_start_on: "2018-10-23 19:32:05 UTC", eligibility_date: "2018-10-23 19:32:05 UTC")
    hbx_enrollment.save
    hbx_enrollment.reload

    FactoryBot.create(:special_enrollment_period, family: family)
  end

  context "GET new" do
    let(:hbx_enrollment_member) { FactoryBot.build(:hbx_enrollment_member) }
    let(:family_member) { family.primary_family_member }
    it "return http success" do
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id}
      expect(response).to have_http_status(:success)
    end

    # it "returns to family home page when employee is not under open enrollment" do
    #   sign_in user
    #   employee_roles = [employee_role]
    #   allow(person).to receive(:employee_roles).and_return(employee_roles)
    #   allow(employee_roles).to receive(:detect).and_return(employee_role)
    #   allow(employee_role).to receive(:is_under_open_enrollment?).and_return(false)
    #   get :new, person_id: person.id, employee_role_id: employee_role.id
    #   expect(response).to redirect_to(family_account_path)
    #   expect(flash[:alert]).to eq "You can only shop for plans during open enrollment."
    # end

    it "return blank change_plan" do
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id}
      expect(assigns(:change_plan)).to eq ""
    end

    it "return change_plan" do
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id, change_plan: "change"}
      expect(assigns(:change_plan)).to eq "change"
    end

    it "should get person" do
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id}
      expect(assigns(:person)).to eq person
    end

    it "should get hbx_enrollment when has active hbx_enrollments and in qle flow" do
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return true
      # FIXME: This is no better than mocking the controller itself on the
      # #selected_enrollment method - and we need to actually mock out the items
      # allow(controller).to receive(:selected_enrollment).and_return hbx_enrollment
      # allow_any_instance_of(GroupSelectionPrevaricationAdapter).to receive(:selected_enrollment).with(family, employee_role).and_return(hbx_enrollment)

      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id, change_plan: 'change_by_qle', market_kind: 'shop', hbx_enrollment_id: hbx_enrollment.id}
      expect(assigns(:hbx_enrollment)).to eq hbx_enrollment
    end

    it "should get coverage_family_members_for_cobra when has active hbx_enrollments and in open enrollment" do
      allow(hbx_enrollments).to receive(:shop_market).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:enrolled_and_renewing).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:effective_desc).and_return([hbx_enrollment])
      allow(hbx_enrollment).to receive(:may_terminate_coverage?).and_return true
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return true
      allow(person.employee_roles.first).to receive(:is_cobra_status?).and_return true
      person.employee_roles.first.census_employee.aasm_state = 'cobra_eligible'
      person.employee_roles.first.census_employee.cobra_begin_date = TimeKeeper.date_of_record
      person.employee_roles.first.census_employee.save
      person.employee_roles.first.save
      family.reload
      person.save
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id, market_kind: 'shop'}
      expect(assigns(:coverage_family_members_for_cobra)).to eq [family.primary_family_member]
    end

    it "should get hbx_enrollment when has enrolled hbx_enrollments and in shop qle flow but user has both employee_role and consumer_role" do
      # FIXME: This is no better than mocking the controller itself on the
      # #selected_enrollment method - and we need to actually mock out the items
      # allow(controller).to receive(:selected_enrollment).and_return hbx_enrollment
      # allow_any_instance_of(GroupSelectionPrevaricationAdapter).to receive(:selected_enrollment).with(family, employee_role).and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return true
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id, change_plan: 'change_by_qle', market_kind: 'shop', consumer_role_id: consumer_role.id, hbx_enrollment_id: hbx_enrollment.id}
      expect(assigns(:hbx_enrollment)).to eq hbx_enrollment
    end

    it "should not get hbx_enrollment when has active hbx_enrollments and not in qle flow" do
      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id}
      expect(assigns(:hbx_enrollment)).not_to eq hbx_enrollment
    end

    it "should disable individual market kind if selected market kind is shop in dual role SEP" do
      family.reload
      # FIXME: This is no better than mocking the controller itself on the
      # #selected_enrollment method - and we need to actually mock out the items
      # allow(controller).to receive(:selected_enrollment).and_return hbx_enrollment
      # allow_any_instance_of(GroupSelectionPrevaricationAdapter).to receive(:selected_enrollment).with(family, employee_role).and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return true

      sign_in user
      get :new, params: {person_id: person.id, employee_role_id: employee_role.id, change_plan: 'change_by_qle', market_kind: 'shop', consumer_role_id: consumer_role.id}
      expect(assigns(:disable_market_kind)).to eq "individual"
    end

    context "it should set the instance variables" do

      before do
        allow(HbxEnrollment).to receive(:find).with("123").and_return(hbx_enrollment)
        allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return true
        allow(hbx_enrollment).to receive(:kind).and_return "individual"
        sign_in user
        get :new, params: {person_id: person.id, employee_role_id: employee_role.id, change_plan: 'change_plan', hbx_enrollment_id: "123"}
      end

      it "should set market kind when user select to make changes in open enrollment" do
        expect(assigns(:mc_market_kind)).to eq hbx_enrollment.kind
      end

      it "should set the coverage kind when user click on make changes in open enrollment" do
        expect(assigns(:mc_coverage_kind)).to eq hbx_enrollment.coverage_kind
      end

      it "should set effective on date" do
        expect(assigns(:new_effective_on)).to eq hbx_enrollment.effective_on
      end
    end

    context "individual" do
      let(:benefit_coverage_period) {FactoryBot.build(:benefit_coverage_period)}
      before :each do
        allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
        allow(benefit_coverage_period).to receive(:benefit_packages).and_return [benefit_package]
        allow(person).to receive(:has_active_consumer_role?).and_return true
        allow(person).to receive(:has_active_employee_role?).and_return false
        allow(HbxEnrollment).to receive(:find).and_return nil
        allow(HbxEnrollment).to receive(:calculate_effective_on_from).and_return TimeKeeper.date_of_record
      end

      it "should set session" do
        sign_in user
        get :new, params: {person_id: person.id, consumer_role_id: consumer_role.id, change_plan: "change", hbx_enrollment_id: "123"}
        expect(session[:pre_hbx_enrollment_id]).to eq "123"
      end

      it "should get new_effective_on" do
        sign_in user
        get :new, params: {person_id: person.id, consumer_role_id: consumer_role.id, change_plan: "change", hbx_enrollment_id: "123"}
        expect(assigns(:new_effective_on)).to eq TimeKeeper.date_of_record
      end
    end
  end

  context "GET terminate_selection" do
    it "return http success and render" do
      sign_in
      get :terminate_selection, params: {person_id: person.id}
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:terminate_selection)
    end
  end

  context "GET terminate_confirm" do
    let!(:person_2) {FactoryBot.create(:person, :with_consumer_role)}
    let!(:family_2) {FactoryBot.create(:family, :with_primary_family_member, :person => person_2)}
    let!(:hbx_enrollment_2) { FactoryBot.create(:hbx_enrollment, household: family_2.active_household) }

    it "return http success and render when valid enrollment id given" do
      sign_in user
      get :terminate_selection, params: { person_id: person.id }
      get :terminate_confirm, params: { person_id: person.id, hbx_enrollment_id: hbx_enrollment.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:terminate_confirm)
    end

    it "redirects when invalid enrollment id given" do
      sign_in user
      get :terminate_selection, params: { person_id: person.id }
      get :terminate_confirm, params: { person_id: person.id, hbx_enrollment_id: hbx_enrollment_2.id }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(terminate_selection_insured_group_selections_path)
    end
  end

  context "POST terminate" do

    before do
      sign_in
      request.env["HTTP_REFERER"] = terminate_confirm_insured_group_selections_path(person_id: person.id, hbx_enrollment_id: hbx_enrollment.id)
      allow(HbxEnrollment).to receive(:find).and_return(hbx_enrollment)
    end

    it "should redirect to family home if termination is possible" do
      allow(hbx_enrollment).to receive(:may_terminate_coverage?).and_return(true)
      allow(hbx_enrollment).to receive(:terminate_benefit)
      expect(HbxEnrollment.aasm.state_machine.events[:terminate_coverage].transitions[0].opts.values.include?(:propogate_terminate)).to eq true
      expect(hbx_enrollment.termination_submitted_on).to eq nil
      post :terminate, params: {term_date: TimeKeeper.date_of_record, hbx_enrollment_id: hbx_enrollment.id}
      expect(hbx_enrollment.termination_submitted_on.to_date).to eq(TimeKeeper.datetime_of_record.to_date)
      expect(response).to redirect_to(family_account_path)
    end

    it "should redirect back if hbx enrollment can't be terminated" do
      hbx_enrollment.assign_attributes(aasm_state: "shopping")
      post :terminate, params: {term_date: TimeKeeper.date_of_record, hbx_enrollment_id: hbx_enrollment.id}
      expect(hbx_enrollment.may_terminate_coverage?).to be_falsey
      expect(response).to redirect_to(terminate_confirm_insured_group_selections_path(person_id: person.id, hbx_enrollment_id: hbx_enrollment.id))
    end


    it "should redirect back if termination date is in the past" do
      allow(hbx_enrollment).to receive(:terminate_benefit)
      post :terminate, params: {term_date: TimeKeeper.date_of_record - 10.days, hbx_enrollment_id: hbx_enrollment.id}
      expect(hbx_enrollment.may_terminate_coverage?).to be_truthy
      expect(response).to redirect_to(terminate_confirm_insured_group_selections_path(person_id: person.id, hbx_enrollment_id: hbx_enrollment.id))
    end

  end

  context "POST CREATE" do
    let(:family_member_ids) {{"0" => family.family_members.first.id}}

    before do
      allow(hbx_enrollment).to receive(:is_shop?).and_return(true)
      sign_in
      family.reload
    end

    it "should redirect" do
      sign_in user
      allow(hbx_enrollment).to receive(:save).and_return(true)
      post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids}
      family.reload
      family.active_household.reload
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(insured_plan_shopping_path(id: family.active_household.hbx_enrollments[1].id, market_kind: 'shop', coverage_kind: 'health', enrollment_kind: ''))
    end

    it "with change_plan" do
      user = FactoryBot.create(:user, id: 98, person: FactoryBot.create(:person))
      sign_in user
      allow(hbx_enrollment).to receive(:save).and_return(true)
      post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids, change_plan: 'change'}
      family.reload
      family.active_household.reload
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(insured_plan_shopping_path(id: family.active_household.hbx_enrollments[1].id, change_plan: 'change', coverage_kind: 'health', market_kind: 'shop', enrollment_kind: ''))
    end

    it "should raise error if not shoppable" do
      user = FactoryBot.create(:user, id: 98, person: FactoryBot.create(:person))
      plan_year.update_attributes(aasm_state: :approved)
      plan_year.save!
      plan_year.reload
      sign_in user
      allow(hbx_enrollment).to receive(:save).and_return(true)
      post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids, change_plan: 'change'}
      family.reload
      family.active_household.reload
      expect(flash[:error]).to match(/Open enrollment for your employer-sponsored benefits not yet started. Please return on/)
    end

    context "when keep_existing_plan" do
      let(:old_hbx) {hbx_enrollment}

      before :each do
        user = FactoryBot.create(:user, person: FactoryBot.create(:person))
        sign_in user
        allow(old_hbx).to receive(:is_shop?).and_return true
        family.active_household.reload
        post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids, commit: 'Keep existing plan', change_plan: 'change', hbx_enrollment_id: old_hbx.id}
        family.reload
        family.active_household.reload
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(purchase_insured_families_path(change_plan: 'change', coverage_kind: 'health', market_kind: 'shop', hbx_enrollment_id: old_hbx.id))
      end

      it "should get special_enrollment_period_id" do
        expect(family.active_household.hbx_enrollments[1].special_enrollment_period_id).to eq family.earliest_effective_shop_sep.id
      end
    end

    context "family has active sep" do
      let(:person1) { FactoryBot.create(:person, :with_family, :with_employee_role)}
      let(:family1) { person1.primary_family }
      let(:family_member_ids) {{"0" => family1.family_members.first.id}}
      let!(:new_household) {family1.households.where(:id => {"$ne" => family.households.first.id.to_s}).first}
      let(:start_on) { TimeKeeper.date_of_record }

      let(:qle) do
        QualifyingLifeEventKind.create(
          title: "Married",
          tool_tip: "Enroll or add a family member because of marriage",
          action_kind: "add_benefit",
          event_kind_label: "Date of married",
          market_kind: "shop",
          ordinal_position: 15,
          reason: "marriage",
          edi_code: "32-MARRIAGE",
          effective_on_kinds: ["first_of_next_month"],
          pre_event_sep_in_days: 0,
          post_event_sep_in_days: 30,
          is_self_attested: true
        )
      end

      let(:special_enrollment_period) {[double("SpecialEnrollmentPeriod")]}
      let!(:sep) { family1.special_enrollment_periods.create(qualifying_life_event_kind: qle, qle_on: qle.created_at, effective_on_kind: qle.event_kind_label, effective_on: current_effective_date, start_on: start_on, end_on: start_on + 30.days) }
      let(:params) do
        { :person_id => person1.id,
          :employee_role_id => person1.employee_roles.first.id,
          :market_kind => "shop",
          :change_plan => "change_plan",
          :hbx_enrollment_id => hbx_enrollment.id,
          :family_member_ids => family_member_ids,
          :enrollment_kind => 'special_enrollment',
          :coverage_kind => hbx_enrollment.coverage_kind}
      end

      it "should create an hbx enrollment" do
        sign_in user
        post :create, params: params
        expect(assigns(:change_plan)).to eq "change_by_qle"
      end
    end

    context "when keep_existing_plan_id_is_nil" do
      let(:existing_product) { ::BenefitMarkets::Products::Product.new(:id => existing_product_id) }
      let(:old_hbx) { HbxEnrollment.new(:sponsored_benefit_package_id => sponsored_benefit_package_id, :sponsored_benefit_id => sponsored_benefit_id, :product => existing_product) }
      before :each do
        user = FactoryBot.create(:user, person: FactoryBot.create(:person))
        sign_in user
        allow(hbx_enrollments).to receive(:show_enrollments_sans_canceled).and_return []
        allow(hbx_enrollments).to receive(:build).and_return(hbx_enrollment)
        allow(hbx_enrollment).to receive(:save).and_return(true)
        allow(hbx_enrollment).to receive(:plan=).and_return(true)
        allow(HbxEnrollment).to receive(:find).and_return old_hbx
        allow(old_hbx).to receive(:is_shop?).and_return true
        allow(old_hbx).to receive(:family).and_return family
        post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids, commit: 'Keep existing plan', change_plan: 'change', hbx_enrollment_id: old_hbx.id}
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(purchase_insured_families_path(change_plan: 'change', coverage_kind: 'health', market_kind: 'shop', hbx_enrollment_id: old_hbx.id))
      end

      it "should get special enrollment id as nil" do
        expect(flash[:error]).not_to match(/undefined method `id' for nil:NilClass/)
      end
    end

    it "should not render group selection page if valid" do
      sign_in user

      allow(hbx_enrollments).to receive(:show_enrollments_sans_canceled).and_return []
      allow(person).to receive(:employee_roles).and_return([employee_role])
      allow(hbx_enrollment).to receive(:save).and_return(false)

      post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids}
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).not_to eq 'You must select the primary applicant to enroll in the healthcare plan'
      expect(response).not_to redirect_to(new_insured_group_selection_path(person_id: person.id, employee_role_id: employee_role.id, change_plan: '', market_kind: 'shop', enrollment_kind: ''))
    end

    context 'should block user from shopping' do

      it 'when benefit application is in termination pending' do
        initial_application.update_attributes(aasm_state: :termination_pending)
        user = create(:user, id: 190, person: create(:person))
        sign_in user
        post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids}
        expect(flash[:error]).to eq "Your employer is no longer offering health insurance through #{Settings.site.short_name}. Please contact your employer or call our Customer Care Center at 1-888-813-9220."
      end

      it 'when benefit application is terminated' do
        initial_application.update_attributes(aasm_state: :terminated)
        user = create(:user, id: 191, person: create(:person))
        sign_in user
        post :create,params: { person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids}
        expect(flash[:error]).to eq "Your employer is no longer offering health insurance through #{Settings.site.short_name}. Please contact your employer."
      end
    end

    it "for cobra with invalid date" do
      user = FactoryBot.create(:user, id: 196, person: FactoryBot.create(:person))
      sign_in user
      allow(census_employee).to receive(:have_valid_date_for_cobra?).and_return(false)
      allow(census_employee).to receive(:coverage_terminated_on).and_return(TimeKeeper.date_of_record)
      allow(census_employee).to receive(:cobra_begin_date).and_return(TimeKeeper.date_of_record + 1.day)
      allow(hbx_enrollments).to receive(:show_enrollments_sans_canceled).and_return []
      person.employee_roles.first.census_employee.update_attributes(aasm_state: "cobra_eligible", coverage_terminated_on: TimeKeeper.date_of_record, cobra_begin_date: TimeKeeper.date_of_record - 1.day)
      person.reload
      post :create, params: {person_id: person.id, employee_role_id: employee_role.id, family_member_ids: family_member_ids}
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq nil
      family.reload
      expect(response).to redirect_to(insured_plan_shopping_path(id: family.active_household.hbx_enrollments.where(aasm_state: 'shopping').last.id, coverage_kind: 'health', market_kind: 'shop', enrollment_kind: ''))
    end

    it "should render group selection page if without family_member_ids" do
      post :create, params: {person_id: person.id, employee_role_id: employee_role.id}
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq 'You must select at least one Eligible applicant to enroll in the healthcare plan'
      expect(response).to redirect_to(new_insured_group_selection_path(person_id: person.id, employee_role_id: employee_role.id, change_plan: '', market_kind: 'shop', enrollment_kind: ''))
    end
  end

  context 'family with active enrollment and sep' do
    let!(:update_family) {family.special_enrollment_periods.delete_all}
    let!(:hbx_enrollment) {FactoryBot.create(:hbx_enrollment, household: family.active_household, sponsored_benefit_package_id: initial_application.benefit_packages.first.id)}
    let!(:start_on) {TimeKeeper.date_of_record}
    let!(:benefit_package) {hbx_enrollment.sponsored_benefit_package}

    let(:qle) do
      QualifyingLifeEventKind.create(
        title: 'Married',
        tool_tip: 'Enroll or add a family member because of marriage',
        action_kind: 'add_benefit',
        event_kind_label: 'Date of married',
        market_kind: 'shop',
        ordinal_position: 15,
        reason: 'marriage',
        edi_code: '32-MARRIAGE',
        effective_on_kinds: ['first_of_next_month'],
        pre_event_sep_in_days: 0,
        post_event_sep_in_days: 30,
        is_self_attested: true
      )
    end

    let(:sep_params) do
      { qualifying_life_event_kind: qle,
        qle_on: qle.created_at,
        effective_on_kind: qle.event_kind_label,
        effective_on: benefit_package.effective_period.min,
        start_on: start_on,
        end_on: start_on + 30.days}
    end

    it 'should assign change_plan as change_by_qle for make changes on the existing enrollment' do
      family.special_enrollment_periods.create(sep_params)
      sign_in user
      get :new,params: { person_id: person.id, employee_role_id: person.employee_roles.first.id, change_plan: 'change_plan', hbx_enrollment_id: hbx_enrollment.id}
      expect(assigns(:change_plan)).to eq 'change_by_qle'
    end
  end
end
