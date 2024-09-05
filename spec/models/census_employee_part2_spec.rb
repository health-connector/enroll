# frozen_string_literal: true

require 'rails_helper'

require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_site_spec_helpers"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_product_spec_helpers"

RSpec.describe CensusEmployee, type: :model, dbclean: :after_each do

  before :each do
    DatabaseCleaner.clean
  end

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:current_effective_date) { TimeKeeper.date_of_record.end_of_month + 1.day + 1.month }

  let!(:employer_profile) {benefit_sponsorship.profile}
  let!(:organization) {employer_profile.organization}
  # let!(:benefit_sponsor_catalog) {FactoryBot.create(:benefit_markets_benefit_sponsor_catalog, service_areas: [renewal_service_area])}

  let!(:benefit_application) {initial_application}
  let!(:benefit_package) {benefit_application.benefit_packages.first}
  let!(:benefit_group) {benefit_package}
  let(:effective_period_start_on) {TimeKeeper.date_of_record.end_of_month + 1.day + 1.month}
  let(:effective_period_end_on) {effective_period_start_on + 1.year - 1.day}
  let(:effective_period) {effective_period_start_on..effective_period_end_on}

  let(:first_name) {"Lynyrd"}
  let(:middle_name) {"Rattlesnake"}
  let(:last_name) {"Skynyrd"}
  let(:name_sfx) {"PhD"}
  let(:ssn) {"230987654"}
  let(:dob) {TimeKeeper.date_of_record - 31.years}
  let(:gender) {"male"}
  let(:hired_on) {TimeKeeper.date_of_record - 14.days}
  let(:is_business_owner) {false}
  let(:address) {Address.new(kind: "home", address_1: "221 R St, NW", city: "Washington", state: "DC", zip: "20001")}
  let(:autocomplete) {" lynyrd skynyrd"}

  let(:valid_params) do
    {
      employer_profile: employer_profile,
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      name_sfx: name_sfx,
      ssn: ssn,
      dob: dob,
      gender: gender,
      hired_on: hired_on,
      is_business_owner: is_business_owner,
      address: address,
      benefit_sponsorship: organization.active_benefit_sponsorship
    }
  end

  context '.create_benefit_group_assignment' do

    let(:benefit_application) {initial_application}
    let(:organization) {initial_application.benefit_sponsorship.profile.organization}
    let!(:blue_collar_benefit_group) { create(:benefit_sponsors_benefit_packages_benefit_package, title: "blue collar benefit group", benefit_application: benefit_application)}
    let!(:employer_profile) {organization.employer_profile}
    let!(:white_collar_benefit_group) { create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: benefit_application, title: "white collar benefit group")}
    let!(:census_employee) {CensusEmployee.create(**valid_params)}

    before do
      census_employee.benefit_group_assignments.delete_all
    end

    context 'when benefit groups are switched' do
      let!(:white_collar_benefit_group_assignment) do
        create(
          :benefit_sponsors_benefit_group_assignment,
          benefit_group: white_collar_benefit_group,
          census_employee: census_employee,
          start_on: white_collar_benefit_group.start_on,
          end_on: white_collar_benefit_group.end_on
        )
      end

      before do
        [white_collar_benefit_group_assignment].each do |bga|
          if bga.census_employee.employee_role_id.nil?
            person = create(:person, :with_family, first_name: bga.census_employee.first_name, last_name: bga.census_employee.last_name, dob: bga.census_employee.dob, ssn: bga.census_employee.ssn)
            family = person.primary_family
            employee_role = person.employee_roles.build(
              census_employee_id: bga.census_employee.id,
              ssn: person.ssn,
              hired_on: bga.census_employee.hired_on,
              benefit_sponsors_employer_profile_id: bga.census_employee.benefit_sponsors_employer_profile_id
            )
            employee_role.save!
            employee_role = person.employee_roles.last
            bga.census_employee.update_attributes!(employee_role_id: employee_role.id)
          else
            person = bga.census_employee.employee_role.person
            family = person.primary_family
          end
          hbx_enrollment = create(
            :hbx_enrollment,
            household: family.households.last,
            coverage_kind: "health",
            kind: "employer_sponsored",
            benefit_sponsorship_id: bga.census_employee.benefit_sponsorship.id,
            employee_role_id: bga.census_employee.employee_role_id,
            sponsored_benefit_package_id: bga.benefit_package_id
          )
          bga.update_attributes!(hbx_enrollment_id: hbx_enrollment.id)
        end
      end
      it 'should create benefit_group_assignment' do
        expect(census_employee.benefit_group_assignments.size).to eq 1
        expect(census_employee.active_benefit_group_assignment).to eq white_collar_benefit_group_assignment
        census_employee.create_benefit_group_assignment([blue_collar_benefit_group])
        census_employee.reload
        expect(census_employee.benefit_group_assignments.size).to eq 2
        expect(census_employee.active_benefit_group_assignment(blue_collar_benefit_group.start_on)).not_to eq white_collar_benefit_group_assignment
      end

      it 'should cancel current benefit_group_assignment' do
        census_employee.create_benefit_group_assignment([blue_collar_benefit_group])
        census_employee.reload
        white_collar_benefit_group_assignment.reload
        expect(white_collar_benefit_group_assignment.end_on).to eq white_collar_benefit_group_assignment.start_on
      end

    end

    context 'when multiple benefit group assignments with benefit group exists' do
      let!(:blue_collar_benefit_group_assignment1) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: blue_collar_benefit_group, census_employee: census_employee, created_at: TimeKeeper.date_of_record - 2.days)}
      let!(:blue_collar_benefit_group_assignment2) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: blue_collar_benefit_group, census_employee: census_employee, created_at: TimeKeeper.date_of_record - 1.day)}
      let!(:blue_collar_benefit_group_assignment3) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: blue_collar_benefit_group, census_employee: census_employee)}
      let!(:white_collar_benefit_group_assignment) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: white_collar_benefit_group, census_employee: census_employee)}

      before do
        expect(census_employee.benefit_group_assignments.size).to eq 4
        [blue_collar_benefit_group_assignment1, blue_collar_benefit_group_assignment2].each do |bga|
          if bga.census_employee.employee_role_id.nil?
            person = create(:person, :with_family, first_name: bga.census_employee.first_name, last_name: bga.census_employee.last_name, dob: bga.census_employee.dob, ssn: bga.census_employee.ssn)
            family = person.primary_family
            employee_role = person.employee_roles.build(
              census_employee_id: bga.census_employee.id,
              ssn: person.ssn,
              hired_on: bga.census_employee.hired_on,
              benefit_sponsors_employer_profile_id: bga.census_employee.benefit_sponsors_employer_profile_id
            )
            employee_role.save!
            employee_role = person.employee_roles.last
            bga.census_employee.update_attributes!(employee_role_id: employee_role.id)
          else
            person = bga.census_employee.employee_role.person
            family = person.primary_family
          end
          hbx_enrollment = create(
            :hbx_enrollment,
            household: family.households.last,
            coverage_kind: "health",
            kind: "employer_sponsored",
            benefit_sponsorship_id: bga.census_employee.benefit_sponsorship.id,
            employee_role_id: bga.census_employee.employee_role_id,
            sponsored_benefit_package_id: bga.benefit_package_id
          )
          bga.update_attributes!(hbx_enrollment_id: hbx_enrollment.id)
        end
        blue_collar_benefit_group_assignment1.hbx_enrollment.aasm_state = 'coverage_selected'
        blue_collar_benefit_group_assignment1.save!(:validate => false)
        blue_collar_benefit_group_assignment2.hbx_enrollment.aasm_state = 'invalid'
        blue_collar_benefit_group_assignment2.hbx_enrollment.save!(:validate => false)
      end

      # use case doesn't exist in R4
      # Switching benefit packages will create new BGAs
      # No activatin previous BGA

      # it 'should activate benefit group assignment with valid enrollment status' do
        # expect(census_employee.benefit_group_assignments.size).to eq 4
        # expect(census_employee.active_benefit_group_assignment).to eq white_collar_benefit_group_assignment
        # expect(blue_collar_benefit_group_assignment2.activated_at).to be_nil
        # census_employee.create_benefit_group_assignment([blue_collar_benefit_group])
        # expect(census_employee.benefit_group_assignments.size).to eq 4
        # expect(census_employee.active_benefit_group_assignment(blue_collar_benefit_group.start_on)).to eq blue_collar_benefit_group_assignment2
        # blue_collar_benefit_group_assignment2.reload
        # TODO: Need to figure why this is showing up as nil.
        # expect(blue_collar_benefit_group_assignment2.activated_at).not_to be_nil
      # end
    end

    # Test case is already tested in above scenario
    # context 'when none present with given benefit group' do
    #   let!(:blue_collar_benefit_group_assignment) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: blue_collar_benefit_group, census_employee: census_employee)}
    #   it 'should create new benefit group assignment' do
    #     expect(census_employee.benefit_group_assignments.size).to eq 1
    #     expect(census_employee.active_benefit_group_assignment.benefit_group).to eq blue_collar_benefit_group
    #     census_employee.create_benefit_group_assignment([white_collar_benefit_group])
    #     expect(census_employee.benefit_group_assignments.size).to eq 2
    #     expect(census_employee.active_benefit_group_assignment.benefit_group).to eq white_collar_benefit_group
    #   end
    # end
  end

  context "current_state" do
    let(:census_employee) {CensusEmployee.new}

    context "existing_cobra is true" do
      before :each do
        census_employee.existing_cobra = 'true'
      end

      it "should return cobra_terminated" do
        census_employee.aasm_state = CensusEmployee::COBRA_STATES.last
        expect(census_employee.current_state).to eq CensusEmployee::COBRA_STATES.last.humanize
      end
    end

    context "existing_cobra is false" do
      it "should return aasm_state" do
        expect(census_employee.current_state).to eq 'eligible'.humanize
      end
    end
  end

  context "is_cobra_status?" do
    let(:census_employee) {CensusEmployee.new}

    context 'when existing_cobra is true' do
      before :each do
        census_employee.existing_cobra = 'true'
      end

      it "should return true" do
        expect(census_employee.is_cobra_status?).to be_truthy
      end

      it "aasm_state should be cobra_eligible" do
        expect(census_employee.aasm_state).to eq 'cobra_eligible'
      end
    end

    context "when existing_cobra is false" do
      before :each do
        census_employee.existing_cobra = false
      end

      it "should return false when aasm_state not equal cobra" do
        census_employee.aasm_state = 'eligible'
        expect(census_employee.is_cobra_status?).to be_falsey
      end

      it "should return true when aasm_state equal cobra_linked" do
        census_employee.aasm_state = 'cobra_linked'
        expect(census_employee.is_cobra_status?).to be_truthy
      end
    end
  end

  context "existing_cobra" do
    # let(:census_employee) { FactoryBot.create(:census_employee) }
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship
    end

    it "should return true" do
      CensusEmployee::COBRA_STATES.each do |state|
        census_employee.aasm_state = state
        expect(census_employee.existing_cobra).to be_truthy
      end
    end
  end

  context "have_valid_date_for_cobra?" do
    let(:hired_on) {TimeKeeper.date_of_record}
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship,
                        hired_on: hired_on
    end

    before :each do
      census_employee.terminate_employee_role!
    end

    it "can cobra employee_role" do
      census_employee.cobra_begin_date = hired_on + 10.days
      census_employee.coverage_terminated_on = TimeKeeper.date_of_record - Settings.aca.shop_market.cobra_enrollment_period.months.months + 5.days
      census_employee.cobra_begin_date = TimeKeeper.date_of_record
      expect(census_employee.may_elect_cobra?).to be_truthy
    end

    it "can not cobra employee_role" do
      census_employee.cobra_begin_date = hired_on + 10.days
      census_employee.coverage_terminated_on = TimeKeeper.date_of_record - Settings.aca.shop_market.cobra_enrollment_period.months.months - 5.days
      census_employee.cobra_begin_date = TimeKeeper.date_of_record
      expect(census_employee.may_elect_cobra?).to be_falsey
    end

    context "current date is less then 6 months after coverage_terminated_on" do
      before :each do
        census_employee.cobra_begin_date = hired_on + 10.days
        census_employee.coverage_terminated_on = TimeKeeper.date_of_record - Settings.aca.shop_market.cobra_enrollment_period.months.months + 5.days
      end

      it "when cobra_begin_date is early than coverage_terminated_on" do
        census_employee.cobra_begin_date = census_employee.coverage_terminated_on - 5.days
        expect(census_employee.may_elect_cobra?).to be_falsey
      end

      it "when cobra_begin_date is later than 6 months after coverage_terminated_on" do
        census_employee.cobra_begin_date = census_employee.coverage_terminated_on + Settings.aca.shop_market.cobra_enrollment_period.months.months + 5.days
        expect(census_employee.may_elect_cobra?).to be_falsey
      end
    end

    it "can not cobra employee_role" do
      census_employee.cobra_begin_date = hired_on - 10.days
      expect(census_employee.may_elect_cobra?).to be_falsey
    end

    it "can not cobra employee_role without cobra_begin_date" do
      census_employee.cobra_begin_date = nil
      expect(census_employee.may_elect_cobra?).to be_falsey
    end
  end

  context "can_elect_cobra?" do
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship,
                        hired_on: hired_on
    end

    it "should return false when aasm_state is eligible" do
      expect(census_employee.can_elect_cobra?).to be_falsey
    end

    it "should return true when aasm_state is employment_terminated" do
      census_employee.aasm_state = 'employment_terminated'
      expect(census_employee.can_elect_cobra?).to be_truthy
    end

    it "should return true when aasm_state is cobra_terminated" do
      census_employee.aasm_state = 'cobra_terminated'
      expect(census_employee.can_elect_cobra?).to be_falsey
    end
  end

  context "show_plan_end_date?" do
    context "without coverage_terminated_on" do

      let(:census_employee) do
        FactoryBot.build :benefit_sponsors_census_employee,
                         employer_profile: employer_profile,
                         benefit_sponsorship: organization.active_benefit_sponsorship,
                         hired_on: hired_on
      end

      (CensusEmployee::EMPLOYMENT_TERMINATED_STATES + CensusEmployee::COBRA_STATES).uniq.each do |state|
        it "should return false when aasm_state is #{state}" do
          census_employee.aasm_state = state
          expect(census_employee.show_plan_end_date?).to be_falsey
        end
      end
    end

    context "with coverage_terminated_on" do

      let(:census_employee) do
        FactoryBot.create :benefit_sponsors_census_employee,
                          employer_profile: employer_profile,
                          benefit_sponsorship: organization.active_benefit_sponsorship,
                          coverage_terminated_on: TimeKeeper.date_of_record
      end

      CensusEmployee::EMPLOYMENT_TERMINATED_STATES.each do |state|
        it "should return false when aasm_state is #{state}" do
          census_employee.aasm_state = state
          expect(census_employee.show_plan_end_date?).to be_truthy
        end
      end

      (CensusEmployee::COBRA_STATES - CensusEmployee::EMPLOYMENT_TERMINATED_STATES).each do |state|
        it "should return false when aasm_state is #{state}" do
          census_employee.aasm_state = state
          expect(census_employee.show_plan_end_date?).to be_falsey
        end
      end
    end
  end

  context "is_cobra_coverage_eligible?" do

    let(:census_employee) do
      FactoryBot.build :benefit_sponsors_census_employee,
                       employer_profile: employer_profile,
                       benefit_sponsorship: organization.active_benefit_sponsorship
    end

    let(:hbx_enrollment) do
      HbxEnrollment.new(
        aasm_state: "coverage_terminated",
        terminated_on: TimeKeeper.date_of_record,
        coverage_kind: 'health'
      )
    end

    it "should return true when employement is terminated and " do
      allow(Family).to receive(:where).and_return([hbx_enrollment])
      allow(census_employee).to receive(:employment_terminated_on).and_return(TimeKeeper.date_of_record)
      allow(census_employee).to receive(:employment_terminated?).and_return(true)
      expect(census_employee.is_cobra_coverage_eligible?).to be_truthy
    end

    it "should return false when employement is not terminated" do
      allow(census_employee).to receive(:employment_terminated?).and_return(false)
      expect(census_employee.is_cobra_coverage_eligible?).to be_falsey
    end
  end

  context "cobra_eligibility_expired?" do

    let(:census_employee) do
      FactoryBot.build :benefit_sponsors_census_employee,
                       employer_profile: employer_profile,
                       benefit_sponsorship: organization.active_benefit_sponsorship
    end

    it "should return true when coverage is terminated more that 6 months " do
      allow(census_employee).to receive(:coverage_terminated_on).and_return(TimeKeeper.date_of_record - 7.months)
      expect(census_employee.cobra_eligibility_expired?).to be_truthy
    end

    it "should return false when coverage is terminated not more that 6 months " do
      allow(census_employee).to receive(:coverage_terminated_on).and_return(TimeKeeper.date_of_record - 2.months)
      expect(census_employee.cobra_eligibility_expired?).to be_falsey
    end

    it "should return true when employment terminated more that 6 months " do
      allow(census_employee).to receive(:coverage_terminated_on).and_return(nil)
      allow(census_employee).to receive(:employment_terminated_on).and_return(TimeKeeper.date_of_record - 7.months)
      expect(census_employee.cobra_eligibility_expired?).to be_truthy
    end

    it "should return false when employment terminated not more that 6 months " do
      allow(census_employee).to receive(:coverage_terminated_on).and_return(nil)
      allow(census_employee).to receive(:employment_terminated_on).and_return(TimeKeeper.date_of_record - 1.months)
      expect(census_employee.cobra_eligibility_expired?).to be_falsey
    end
  end


  context "is_linked?" do

    let(:census_employee) do
      FactoryBot.build :benefit_sponsors_census_employee,
                       employer_profile: employer_profile,
                       benefit_sponsorship: organization.active_benefit_sponsorship
    end

    it "should return true when aasm_state is employee_role_linked" do
      census_employee.aasm_state = 'employee_role_linked'
      expect(census_employee.is_linked?).to be_truthy
    end

    it "should return true when aasm_state is cobra_linked" do
      census_employee.aasm_state = 'cobra_linked'
      expect(census_employee.is_linked?).to be_truthy
    end

    it "should return false" do
      expect(census_employee.is_linked?).to be_falsey
    end
  end

  context '.enrollments_for_display', dbclean: :before_each do

    include_context "setup renewal application"

    before :each do
      initial_application.destroy
    end

    let(:census_employee) do
      ce = FactoryBot.create(:benefit_sponsors_census_employee,
                             employer_profile: employer_profile,
                             benefit_sponsorship: benefit_sponsorship,
                             dob: TimeKeeper.date_of_record - 30.years)
      person = create(:person, last_name: ce.last_name, first_name: ce.first_name)
      employee_role = build(:benefit_sponsors_employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
      create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_application.benefit_packages.first, census_employee: ce)
      ce.active_benefit_group_assignment.update_attributes!(benefit_package_id: initial_application.benefit_packages.first.id)
      ce.update_attributes({employee_role: employee_role})
      family = Family.find_or_build_from_employee_role(employee_role)
      ce
    end

    let!(:auto_renewing_health_enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "health",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: renewal_application.benefit_packages.first.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id,
                        aasm_state: "auto_renewing")
    end

    let!(:auto_renewing_dental_enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "dental",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: renewal_application.benefit_packages.first.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id,
                        aasm_state: "auto_renewing")
    end

    let(:enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "health",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: census_employee.active_benefit_group.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                        aasm_state: "coverage_selected")
    end

    shared_examples_for "enrollments for display" do |state, status, result|
      let!(:health_enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: census_employee.employee_role.person.primary_family.active_household,
          coverage_kind: "health",
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: census_employee.active_benefit_package.id,
          employee_role_id: census_employee.employee_role.id,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          aasm_state: state
        )
      end

      let!(:dental_enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: census_employee.employee_role.person.primary_family.active_household,
          coverage_kind: "dental",
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: census_employee.active_benefit_package.id,
          employee_role_id: census_employee.employee_role.id,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          aasm_state: state
        )
      end

      it "should #{status}return #{state} health enrollment" do
        expect(census_employee.enrollments_for_display[0].try(:aasm_state) == state).to eq result
      end

      it "should #{status}return #{state} dental enrollment" do
        expect(census_employee.enrollments_for_display[1].try(:aasm_state) == state).to eq result
      end
    end

    it_behaves_like "enrollments for display", "coverage_selected", "", true
    it_behaves_like "enrollments for display", "coverage_enrolled", "", true
    it_behaves_like "enrollments for display", "coverage_termination_pending", "", true
    it_behaves_like "enrollments for display", "coverage_terminated", "not ", false
    it_behaves_like "enrollments for display", "coverage_expired", "not ", false
    it_behaves_like "enrollments for display", "shopping", "not ", false

    it 'should return auto renewing health enrollment' do
      renewal_application.approve_application! if renewal_application.may_approve_application?
      benefit_sponsorship.benefit_applications << renewal_application
      benefit_sponsorship.save!
      expect(census_employee.enrollments_for_display[0]).to eq auto_renewing_health_enrollment
    end

    it 'should return auto renewing dental enrollment' do
      renewal_application.approve_application! if renewal_application.may_approve_application?
      benefit_sponsorship.benefit_applications << renewal_application
      benefit_sponsorship.save
      expect(census_employee.enrollments_for_display[1]).to eq auto_renewing_dental_enrollment
    end

    it "should return current and renewing coverages" do
      renewal_application.approve_application! if renewal_application.may_approve_application?
      benefit_sponsorship.benefit_applications << renewal_application
      benefit_sponsorship.save
      enrollment
      expect(census_employee.enrollments_for_display).to eq [enrollment, auto_renewing_health_enrollment, auto_renewing_dental_enrollment]
    end
  end

  context 'enrollments_for_display - when employer has off-cycle benefit application', dbclean: :before_each do

    before do
      allow(::BenefitMarkets::Products::ProductRateCache).to receive(:age_bounding).and_return(20)
      allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate).and_return(15)
    end

    let(:date)  { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
    let(:current_effective_date)  { date.prev_year }

    include_context 'setup initial benefit application'

    let(:renewal_application) do
      renewal = initial_application.renew
      renewal.save
      renewal
    end

    let(:census_employee) do
      ce =
        FactoryBot.create(
          :benefit_sponsors_census_employee,
          employer_profile: employer_profile,
          benefit_sponsorship: benefit_sponsorship,
          dob: TimeKeeper.date_of_record - 30.years
        )
      person = create(:person, last_name: ce.last_name, first_name: ce.first_name)
      employee_role = build(:benefit_sponsors_employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
      create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_application.benefit_packages.first, census_employee: ce)
      ce.active_benefit_group_assignment.update_attributes!(benefit_package_id: initial_application.benefit_packages.first.id)
      ce.update_attributes({employee_role: employee_role})
      Family.find_or_build_from_employee_role(employee_role)
      ce
    end

    let(:terminated_on) { TimeKeeper.date_of_record.end_of_month }
    let!(:off_cycle_effective_date) { terminated_on.next_day }


    let(:off_cycle_benefit_sponsor_catalog) do
      benefit_sponsorship.benefit_sponsor_catalog_for(off_cycle_effective_date)
    end

    let!(:off_cycle_application) do
      ben_app = create(
        :benefit_sponsors_benefit_application,
        :with_benefit_sponsor_catalog,
        :with_benefit_package,
        passed_benefit_sponsor_catalog: off_cycle_benefit_sponsor_catalog,
        aasm_state: :enrollment_open,
        benefit_sponsorship: benefit_sponsorship,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas,
        fte_count: 5,
        pte_count: 0,
        msp_count: 0
      )
      ben_app.benefit_application_items.create(effective_period: effective_period, sequence_id: 1, state: :enrollment_open)
      ben_app
    end

    let(:off_cycle_benefit_package) { off_cycle_application.benefit_packages[0] }
    let(:off_cycle_benefit_group_assignment) do
      FactoryBot.create(
        :benefit_sponsors_benefit_group_assignment,
        benefit_group: off_cycle_benefit_package,
        census_employee: census_employee,
        start_on: off_cycle_benefit_package.start_on,
        end_on: off_cycle_benefit_package.end_on
      )
    end

    let!(:off_cycle_health_enrollment) do
      FactoryBot.create(
        :hbx_enrollment,
        household: census_employee.employee_role.person.primary_family.active_household,
        coverage_kind: "health",
        kind: "employer_sponsored",
        benefit_sponsorship_id: benefit_sponsorship.id,
        sponsored_benefit_package_id: off_cycle_benefit_package.id,
        employee_role_id: census_employee.employee_role.id,
        benefit_group_assignment_id: off_cycle_benefit_group_assignment.id,
        aasm_state: 'coverage_selected'
      )
    end

    before do
      updated_dates = initial_application.effective_period.min.to_date..terminated_on
      initial_application.benefit_application_items.create(
        effective_period: updated_dates,
        action_type: :change,
        action_kind: 'voluntary',
        action_reason: 'voluntary',
        state: :terminated,
        sequence_id: 1
      )
      initial_application.terminate_enrollment!
      renewal_application.benefit_application_items.create(
        effective_period: initial_application.effective_period,
        action_type: :change,
        state: :cancel,
        sequence_id: 1
      )
      renewal_application.cancel!
    end

    it 'should return off cycle enrollment' do
      expect(census_employee.enrollments_for_display[0]).to eq off_cycle_health_enrollment
    end
  end

  context '.past_enrollments' do
    include_context "setup renewal application"

    before do
      benefit_application.expire!
    end

    let(:census_employee) do
      ce = FactoryBot.create(:benefit_sponsors_census_employee,
                             employer_profile: employer_profile,
                             benefit_sponsorship: benefit_sponsorship,
                             dob: TimeKeeper.date_of_record - 30.years)

      person = create(:person, last_name: ce.last_name, first_name: ce.first_name)
      employee_role = build(:benefit_sponsors_employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
      create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_application.benefit_packages.first, census_employee: ce)
      ce.update_attributes({employee_role: employee_role})
      family = Family.find_or_build_from_employee_role(employee_role)
      ce
    end

    let(:past_benefit_group_assignment) {  create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_application.benefit_packages.first, census_employee: census_employee) }

    let!(:enrollment) do
      create(
        :hbx_enrollment,
        household: census_employee.employee_role.person.primary_family.active_household,
        coverage_kind: "health",
        kind: "employer_sponsored",
        benefit_sponsorship_id: benefit_sponsorship.id,
        sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
        employee_role_id: census_employee.employee_role.id,
        benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
        aasm_state: "coverage_selected"
      )
    end

    let(:past_benefit_group_assignment) { FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_application.benefit_packages.first, census_employee: census_employee, is_active: false) }

    let!(:enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "health",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                        aasm_state: "coverage_selected")
    end
    let!(:past_expired_enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "health",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: past_benefit_group_assignment.id,
                        aasm_state: "coverage_expired")
    end

    let!(:canceled_enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: census_employee.employee_role.person.primary_family.active_household,
                        coverage_kind: "health",
                        kind: "employer_sponsored",
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                        employee_role_id: census_employee.employee_role.id,
                        benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                        aasm_state: "coverage_canceled")
    end

    it 'should return past expired enrollment' do
      expect(census_employee.past_enrollments.to_a.include?(past_expired_enrollment)).to eq true
    end

    it 'should NOT return current active enrollment' do
      expect(census_employee.past_enrollments.to_a.include?(enrollment)).to eq false
    end

    it 'should NOT return canceled enrollment' do
      expect(census_employee.past_enrollments.to_a.include?(canceled_enrollment)).to eq false
    end
  end

  context 'editing a CensusEmployee SSN/DOB that is in a linked status' do

    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship
    end

    let(:person) {FactoryBot.create(:person)}

    let(:user) {double("user")}
    let(:employee_role) {FactoryBot.build(:benefit_sponsors_employee_role, employer_profile: organization.employer_profile)}


    it 'should allow Admins to edit a CensusEmployee SSN/DOB that is in a linked status' do
      allow(user).to receive(:has_hbx_staff_role?).and_return true # Admin
      allow(person).to receive(:employee_roles).and_return [employee_role]
      allow(employee_role).to receive(:census_employee).and_return census_employee
      allow(census_employee).to receive(:aasm_state).and_return "employee_role_linked"
      CensusEmployee.update_census_employee_records(person, user)
      expect(census_employee.ssn).to eq person.ssn
      expect(census_employee.dob).to eq person.dob
    end

    it 'should NOT allow Non-Admins to edit a CensusEmployee SSN/DOB that is in a linked status' do
      allow(user).to receive(:has_hbx_staff_role?).and_return false # Non-Admin
      allow(person).to receive(:employee_roles).and_return [employee_role]
      allow(employee_role).to receive(:census_employee).and_return census_employee
      allow(census_employee).to receive(:aasm_state).and_return "employee_role_linked"
      CensusEmployee.update_census_employee_records(person, user)
      expect(census_employee.ssn).not_to eq person.ssn
      expect(census_employee.dob).not_to eq person.dob
    end
  end

  context "check_hired_on_before_dob" do

    let(:census_employee) do
      FactoryBot.build :benefit_sponsors_census_employee,
                       employer_profile: employer_profile,
                       benefit_sponsorship: organization.active_benefit_sponsorship
    end

    it "should fail" do
      census_employee.dob = TimeKeeper.date_of_record - 30.years
      census_employee.hired_on = TimeKeeper.date_of_record - 31.years
      expect(census_employee.save).to be_falsey
      expect(census_employee.errors[:hired_on].any?).to be_truthy
      expect(census_employee.errors[:hired_on].to_s).to match(/date can't be before  date of birth/)
    end
  end

  context ".is_enrolled_or_renewed?" do
    let(:benefit_group_assignment) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group)}
    let(:census_employee) do
      FactoryBot.create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: organization.active_benefit_sponsorship,
        benefit_group_assignments: [benefit_group_assignment]
      )
    end

    let(:enrolled_hbx_enrollment_double) { double('EnrolledHbxEnrollment', aasm_state: 'coverage_selected', sponsored_benefit_package_id: benefit_group.id) }

    it "returns false when no enrollment present" do
      expect(census_employee.is_enrolled_or_renewed?).to be_falsey
    end

    it "returns true with enrolled enrollment" do
      allow(benefit_group_assignment).to receive(:active_enrollments).and_return([enrolled_hbx_enrollment_double])
      expect(census_employee.is_enrolled_or_renewed?).to be_truthy
    end
  end

  context ".is_employee_covered?" do
    let(:benefit_group_assignment) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group)}
    let(:census_employee) do
      FactoryBot.create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: organization.active_benefit_sponsorship,
        benefit_group_assignments: [benefit_group_assignment]
      )
    end

    let(:enrolled_family_double) { double('EnrolledFamily', id: '1') }

    before do
      allow(census_employee).to receive(:employee_role).and_return double("EmployeeRole")
      allow(census_employee).to receive(:family).and_return enrolled_family_double
    end

    it "returns false when no covered employee present" do
      expect(census_employee.is_employee_covered?).to be_falsey
    end

    it "returns true with covered employee" do
      allow(benefit_group_assignment).to receive(:covered_families_with_benefit_assignemnt).and_return([enrolled_family_double])
      expect(census_employee.is_employee_covered?).to be_truthy
    end
  end

  context "expected to enroll" do

    let!(:valid_waived_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship,
                        expected_selection: 'waive'
    end

    let!(:enrolling_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship,
                        expected_selection: 'enroll'
    end

    let!(:invalid_waive) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship,
                        expected_selection: 'will_not_participate'
    end

    it "returns true for enrolling employees" do
      expect(enrolling_employee.expected_to_enroll?).to be_truthy
    end

    it "returns false for non enrolling employees" do
      expect(valid_waived_employee.expected_to_enroll?).to be_falsey
      expect(invalid_waive.expected_to_enroll?).to be_falsey
    end

    it "counts waived and enrollees when considering group size" do
      expect(valid_waived_employee.expected_to_enroll_or_valid_waive?).to be_truthy
      expect(enrolling_employee.expected_to_enroll_or_valid_waive?).to be_truthy
      expect(invalid_waive.expected_to_enroll_or_valid_waive?).to be_falsey
    end
  end

  context "when active employeees opt to waive" do

    let(:census_employee) do
      FactoryBot.create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: organization.active_benefit_sponsorship,
        benefit_group_assignments: [benefit_group_assignment]
      )
    end
    let(:waived_hbx_enrollment_double) { double('WaivedHbxEnrollment', is_coverage_waived?: true, aasm_state: "inactive", coverage_kind: 'health', sponsored_benefit_package_id: benefit_group.id) }
    let(:coverage_selected_hbx_enrollment_double) { double('CoveredHbxEnrollment', is_coverage_waived?: false, aasm_state: "coverage_selected", coverage_kind: 'health', sponsored_benefit_package_id: benefit_group.id) }

    let(:benefit_group_assignment) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group)}

    it "returns true when employees waive the coverage" do
      allow(benefit_group_assignment).to receive(:hbx_enrollments).and_return([waived_hbx_enrollment_double])
      expect(census_employee.waived?).to be_truthy
    end
    it "returns false for employees who are enrolling" do
      allow(benefit_group_assignment).to receive(:hbx_enrollments).and_return([coverage_selected_hbx_enrollment_double])
      expect(census_employee.waived?).to be_falsey
    end
  end

  context "when active employeees has renewal benefit group" do
    let(:census_employee) {CensusEmployee.new(**valid_params)}
    let(:benefit_group_assignment) {create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee)}
    let(:waived_hbx_enrollment_double) { double('WaivedHbxEnrollment', is_coverage_waived?: true, aasm_state: "inactive", coverage_kind: 'health', sponsored_benefit_package_id: benefit_group.id) }
    before do
      benefit_group_assignment.update_attribute(:updated_at, benefit_group_assignment.updated_at + 1.day)
      benefit_group_assignment.plan_year.update_attribute(:aasm_state, "renewing_enrolled")
    end

    it "returns false when employees waive the coverage" do
      expect(census_employee.waived?).to be_falsey
    end

    it "returns true for employees who are enrolling" do
      allow(benefit_group_assignment).to receive(:hbx_enrollments).and_return([waived_hbx_enrollment_double])
      expect(census_employee.waived?).to be_truthy
    end
  end

  context "when active employeees have health and dental renewal benefit group" do
    let(:census_employee) {CensusEmployee.new(**valid_params)}
    let(:benefit_group_assignment) {create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee)}
    let(:waived_hbx_enrollment_double) { double('WaivedHbxEnrollment', coverage_kind: 'dental', aasm_state: "renewing_waived", is_coverage_waived?: true, sponsored_benefit_package_id: benefit_group.id) }
    let(:coverage_selected_hbx_enrollment_double) { double('CoveredHbxEnrollment', is_coverage_waived?: false, aasm_state: "auto_renewing", coverage_kind: 'health', sponsored_benefit_package_id: benefit_group.id) }

    before do
      benefit_group_assignment.update_attribute(:updated_at, benefit_group_assignment.updated_at + 1.day)
      benefit_group_assignment.plan_year.update_attribute(:aasm_state, "renewing_enrolled")
    end

    it "returns false when employees waive the dental coverage and enroll health" do
      allow(benefit_group_assignment).to receive(:hbx_enrollments).and_return([waived_hbx_enrollment_double, coverage_selected_hbx_enrollment_double])
      expect(census_employee.waived?).to be_falsey
    end
  end

  context '.renewal_benefit_group_assignment' do
    include_context "setup renewal application"

    let(:renewal_benefit_group) { renewal_application.benefit_packages.first}
    let(:renewal_product_package2) { renewal_application.benefit_sponsor_catalog.product_packages.detect {|package| package.package_kind != renewal_benefit_group.plan_option_kind} }
    let!(:renewal_benefit_group2) { create(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, product_package: renewal_product_package2, benefit_application: renewal_application, title: 'Benefit Package 2 Renewal')}
    let(:census_employee) { create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship)}
    let!(:benefit_group_assignment_two) { BenefitGroupAssignment.on_date(census_employee, renewal_effective_date) }

    it "should select the latest renewal benefit group assignment" do
      expect(census_employee.renewal_benefit_group_assignment).to eq benefit_group_assignment_two
    end

    context 'when multiple renewal assignments present' do

      context 'and latest assignment has enrollment associated' do
        let(:benefit_group_assignment_three) {create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_benefit_group, census_employee: census_employee, end_on: renewal_benefit_group.end_on)}
        let(:enrollment) { double }

        before do
          benefit_group_assignment_two.update!(end_on: benefit_group_assignment_two.start_on)
          allow(benefit_group_assignment_three).to receive(:hbx_enrollment).and_return(enrollment)
        end

        it 'should return assignment with coverage associated' do
          expect(census_employee.renewal_benefit_group_assignment).to eq benefit_group_assignment_three
        end
      end

      context 'and ealier assignment has enrollment associated' do
        let(:benefit_group_assignment_three) { create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_benefit_group, census_employee: census_employee)}
        let(:enrollment) { double }

        before do
          allow(benefit_group_assignment_two).to receive(:hbx_enrollment).and_return(enrollment)
        end

        it 'should return assignment with coverage associated' do
          expect(census_employee.renewal_benefit_group_assignment).to eq benefit_group_assignment_two
        end
      end
    end

    context 'when new benefit package is assigned' do

      it 'should cancel the previous benefit group assignment' do
        previous_bga = census_employee.renewal_benefit_group_assignment
        census_employee.renewal_benefit_group_assignment = renewal_benefit_group2.id
        census_employee.save
        census_employee.reload
        expect(previous_bga.canceled?).to be_truthy
      end

      it 'should create new benefit group assignment' do
        previous_bga = census_employee.renewal_benefit_group_assignment
        census_employee.renewal_benefit_group_assignment = renewal_benefit_group2.id
        census_employee.save
        census_employee.reload
        expect(census_employee.renewal_benefit_group_assignment).not_to eq previous_bga
      end
    end
  end

  context "and congressional newly designated employees are added" do
    let(:employer_profile_congressional) {employer_profile}
    let(:plan_year) {benefit_application}
    let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: civil_servant)}
    let(:civil_servant) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile_congressional, benefit_sponsorship: organization.active_benefit_sponsorship)}
    let(:initial_state) {"eligible"}
    let(:eligible_state) {"newly_designated_eligible"}
    let(:linked_state) {"newly_designated_linked"}
    let(:employee_linked_state) {"employee_role_linked"}

    specify {expect(civil_servant.aasm_state).to eq initial_state}

    it "should transition to newly designated eligible state" do
      expect {civil_servant.newly_designate!}.to change(civil_servant, :aasm_state).to eq eligible_state
    end

    context "and the census employee is associated with an employee role" do
      before do
        civil_servant.benefit_group_assignments = [benefit_group_assignment]
        civil_servant.newly_designate
      end

      it "should transition to newly designated linked state" do
        expect {civil_servant.link_employee_role!}.to change(civil_servant, :aasm_state).to eq linked_state
      end

      context "and the link to employee role is removed" do
        before do
          civil_servant.benefit_group_assignments = [benefit_group_assignment]
          civil_servant.aasm_state = linked_state
          civil_servant.save!
        end

        it "should revert to 'newly designated eligible' state" do
          expect {civil_servant.delink_employee_role!}.to change(civil_servant, :aasm_state).to eq eligible_state
        end
      end
    end

    context "and multiple newly designated employees are present in database" do
      let(:second_civil_servant) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile_congressional, benefit_sponsorship: organization.active_benefit_sponsorship)}

      before do
        civil_servant.benefit_group_assignments = [benefit_group_assignment]
        civil_servant.newly_designate!

        second_civil_servant.benefit_group_assignments = [benefit_group_assignment]
        second_civil_servant.save!
        second_civil_servant.newly_designate!
        second_civil_servant.link_employee_role!
      end

      it "the scope should find them all" do
        expect(CensusEmployee.newly_designated.size).to eq 2
      end

      it "the scope should find the eligible census employees" do
        expect(CensusEmployee.eligible.size).to eq 1
      end

      it "the scope should find the linked census employees" do
        expect(CensusEmployee.linked.size).to eq 1
      end

      context "and new plan year begins, ending 'newly designated' status" do
        let!(:hbx_profile) {FactoryBot.create(:hbx_profile, :open_enrollment_coverage_period)}
        # before do
        #   benefit_application.update_attributes(aasm_state: :enrollment_closed)
        #   TimeKeeper.set_date_of_record_unprotected!(Date.today.end_of_year)
        #   TimeKeeper.set_date_of_record(Date.today.end_of_year + 1.day)
        # end

        xit "should transition 'newly designated eligible' status to initial state" do
          expect(civil_servant.aasm_state).to eq eligible_state
        end

        xit "should transition 'newly designated linked' status to linked state" do
          expect(second_civil_servant.aasm_state).to eq employee_linked_state
        end
      end

    end


  end

  describe "#trigger_notice" do
    let(:census_employee) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship)}
    let(:employee_role) {FactoryBot.build(:benefit_sponsors_employee_role, :census_employee => census_employee)}
    it "should trigger job in queue" do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs = []
      census_employee.trigger_notice("ee_sep_request_accepted_notice")
      queued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job_info|
        job_info[:job] == ShopNoticesNotifierJob
      end
      expect(queued_job[:args]).to eq [census_employee.id.to_s, 'ee_sep_request_accepted_notice']
    end
  end

  describe "search_hash" do
    context 'census search query' do

      it "query string for census employee firstname or last name" do
        employee_search = "test1"
        expected_result = {"$or" => [{"$or" => [{"first_name" => /test1/i}, {"last_name" => /test1/i}]}, {"encrypted_ssn" => "+MZq0qWj9VdyUd9MifJWpQ=="}]}
        result = CensusEmployee.search_hash(employee_search)
        expect(result).to eq expected_result
      end

      it "census employee query string for full name" do
        employee_search = "test1 test2"
        expected_result = {"$or" => [{"$and" => [{"first_name" => /test1|test2/i}, {"last_name" => /test1|test2/i}]}, {"encrypted_ssn" => "0m50gjJW7mR4HLnepJyFmg=="}]}
        result = CensusEmployee.search_hash(employee_search)
        expect(result).to eq expected_result
      end

    end
  end

  describe "#has_no_hbx_enrollments?" do
    let(:census_employee) { FactoryBot.create(:census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship) }

    it "should return true if no employee role linked" do
      expect(census_employee.send(:has_no_hbx_enrollments?)).to eq true
    end

    it "should return true if employee role present & no enrollment present" do
      allow(census_employee).to receive(:employee_role).and_return double("EmployeeRole")
      allow(census_employee).to receive(:family).and_return double("Family", id: '1')
      expect(census_employee.send(:has_no_hbx_enrollments?)).to eq true
    end

    it "should return true if employee role present & no active enrollment present" do
      allow(census_employee).to receive(:employee_role).and_return double("EmployeeRole")
      allow(census_employee).to receive(:family).and_return double("Family", id: '1')
      allow(census_employee.active_benefit_group_assignment).to receive(:hbx_enrollment).and_return double("HbxEnrollment", aasm_state: "coverage_canceled")
      expect(census_employee.send(:has_no_hbx_enrollments?)).to eq true
    end

    it "should return false if employee role present & active enrollment present" do
      allow(census_employee).to receive(:employee_role).and_return double("EmployeeRole")
      allow(census_employee).to receive(:family).and_return double("Family", id: '1')
      allow(census_employee.active_benefit_group_assignment).to receive(:hbx_enrollment).and_return double("HbxEnrollment", aasm_state: "coverage_selected")
      expect(census_employee.send(:has_no_hbx_enrollments?)).to eq false
    end
  end

  describe "#benefit_package_for_date", dbclean: :after_each do
    let(:site) {FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)}
    let(:employer_profile) {benefit_sponsorship.profile}
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: benefit_sponsorship
    end

    before do
      census_employee.save
    end

    context "when ER has imported applications" do
      let(:bga1) do
        double("BenefitGroupAssignment", created_at: TimeKeeper.date_of_record - 25.days, start_on: TimeKeeper.date_of_record - 2.days, benefit_end_date: TimeKeeper.date_of_record + 2.days, is_active: false,
                                         benefit_package: double("benefit_package", is_active: true))
      end
      let(:bga2) do
        double("BenefitGroupAssignment", created_at: TimeKeeper.date_of_record, start_on: TimeKeeper.date_of_record - 2.days, benefit_end_date: TimeKeeper.date_of_record + 2.days, is_active: false,
                                         benefit_package: double("benefit_package", is_active: true))
      end

      it "should return nil if given effective_on date is in imported benefit application" do
        initial_application.update_attributes(aasm_state: :imported)
        allow(bga1).to receive(:is_active?).and_return(false)
        allow(bga2).to receive(:is_active?).and_return(false)
        coverage_date = initial_application.end_on - 1.month
        expect(census_employee.reload.benefit_package_for_date(coverage_date)).to eq nil
      end

      it "should return nil if given coverage_date is not between the bga start_on and end_on dates" do
        allow(bga1).to receive(:is_active?).and_return(false)
        allow(bga2).to receive(:is_active?).and_return(false)
        initial_application.update_attributes(aasm_state: :imported)
        coverage_date = census_employee.benefit_group_assignments.first.start_on - 1.month
        expect(census_employee.benefit_group_assignment_for_date(coverage_date)).to eq nil
      end

      it "should return latest bga when multiple present" do
        allow(bga1).to receive(:is_active?).and_return(false)
        allow(bga2).to receive(:is_active?).and_return(true)
        allow(census_employee).to receive(:benefit_group_assignments).and_return [bga1, bga2]
        expect(census_employee.benefit_group_assignment_for_date(TimeKeeper.date_of_record)).to eq bga2
      end
    end

    context "when ER has active and renewal benefit applications" do
      include_context "setup renewal application"

      let(:benefit_group_assignment_two) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_application.benefit_packages.first, census_employee: census_employee)}

      it "should return active benefit_package if given effective_on date is in active benefit application" do
        coverage_date = initial_application.end_on - 1.month
        expect(census_employee.benefit_package_for_date(coverage_date)).to eq renewal_application.benefit_packages.first
      end

      it "should return renewal benefit_package if given effective_on date is in renewal benefit application" do
        benefit_group_assignment_two
        coverage_date = renewal_application.start_on
        expect(census_employee.benefit_package_for_date(coverage_date)).to eq renewal_application.benefit_packages.first
      end
    end

    context "when ER has imported, mid year conversion and renewal benefit applications" do

      let(:myc_application) do
        FactoryBot.build(
          :benefit_sponsors_benefit_application,
          :with_benefit_package,
          benefit_sponsorship: benefit_sponsorship,
          aasm_state: :active,
          default_effective_period: ((benefit_application.end_on - 2.months).next_day..benefit_application.end_on),
          default_open_enrollment_period: ((benefit_application.end_on - 1.year).next_day - 1.month..(benefit_application.end_on - 1.year).next_day - 15.days)
        )
      end

      let(:mid_year_benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: myc_application.benefit_packages.first, census_employee: census_employee)}
      let(:termination_date) {myc_application.start_on.prev_day}

      before do
        benefit_sponsorship.benefit_applications.each do |ba|
          next if ba == myc_application

          updated_dates = benefit_application.effective_period.min.to_date..termination_date.to_date
          ba.benefit_application_items.create(effective_period: updated_dates, sequence_id: 1, state: :terminated)
          ba.terminate_enrollment!
        end
        benefit_sponsorship.benefit_applications << myc_application
        benefit_sponsorship.save
        census_employee.benefit_group_assignments.first.reload
      end

      it "should return mid year benefit_package if given effective_on date is in both imported & mid year benefit application" do
        coverage_date = myc_application.start_on
        mid_year_benefit_group_assignment
        expect(census_employee.benefit_package_for_date(coverage_date)).to eq myc_application.benefit_packages.first
      end
    end
  end

  describe "#is_cobra_possible" do
    let(:params) { valid_params.merge(:aasm_state => aasm_state) }
    let(:census_employee) { CensusEmployee.new(**params) }

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"cobra_linked"}

      it "should return false" do
        expect(census_employee.is_cobra_possible?).to eq false
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"employee_termination_pending"}

      it "should return false" do
        expect(census_employee.is_cobra_possible?).to eq true
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"employment_terminated"}

      before do
        allow(census_employee).to receive(:employment_terminated_on).and_return TimeKeeper.date_of_record.last_month
      end

      it "should return false" do
        expect(census_employee.is_cobra_possible?).to eq true
      end
    end
  end

  describe "#is_rehired_possible" do
    let(:params) { valid_params.merge(:aasm_state => aasm_state) }
    let(:census_employee) { CensusEmployee.new(**params) }

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"cobra_eligible"}

      it "should return false" do
        expect(census_employee.is_rehired_possible?).to eq false
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"rehired"}

      it "should return false" do
        expect(census_employee.is_rehired_possible?).to eq false
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"cobra_terminated"}

      it "should return false" do
        expect(census_employee.is_rehired_possible?).to eq true
      end
    end
  end

  describe "Employee enrolling for cobra" do

    context "and employer reinstate employee as cobra", dbclean: :after_each do
      # include_context "setup benefit market with market catalogs and product packages"
      include_context 'setup initial benefit application'

      let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year - 1, 6, 1)}
      let(:coverage_kind) { 'health' }
      let(:user) { FactoryBot.create(:user)}
      let(:person) { FactoryBot.create(:person) }
      let(:census_employee) do
        ce = create(
          :benefit_sponsors_census_employee,
          employer_profile: employer_profile,
          benefit_sponsorship: organization.active_benefit_sponsorship
        )
        employee_role = build(:benefit_sponsors_employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
        ce.update_attributes({employee_role: employee_role})
        Family.find_or_build_from_employee_role(employee_role)
        ce
      end

      let(:employment_termination_date) { initial_application.start_on + 15.days }

      context "when employee enrolled previously", dbclean: :after_each do
        let(:benefit_group) { initial_application.benefit_packages.first}
        let!(:active_bga) {  create(:benefit_sponsors_benefit_group_assignment, benefit_group: initial_application.benefit_packages.first, census_employee: census_employee) }

        let!(:active_enrollment) do
          create(
            :hbx_enrollment,
            household: census_employee.employee_role.person.primary_family.active_household,
            coverage_kind: "health",
            kind: "employer_sponsored",
            effective_on: initial_application.start_on,
            benefit_sponsorship_id: benefit_sponsorship.id,
            sponsored_benefit_package_id: benefit_group.id,
            employee_role_id: census_employee.employee_role.id,
            benefit_group_assignment_id: active_bga.id,
            aasm_state: "coverage_selected"
          )
        end

        let(:cobra_begin_date) { employment_termination_date.end_of_month + 1.day }

        before do
          TimeKeeper.set_date_of_record_unprotected!(initial_application.start_on.next_month + 15.days)
          census_employee.employee_role.update(census_employee_id: census_employee.id)
          allow(census_employee).to receive(:employee_record_claimed?).and_return(true)
          # census_employee.employee_role = (employee_role)
          census_employee.terminate_employment(employment_termination_date)
          census_employee.reload
          census_employee.update_for_cobra(cobra_begin_date, user)
          census_employee.reload
        end

        after do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        it 'should reinstate employee cobra coverage' do
          person.reload
          cobra_enrollment = person.primary_family.active_household.hbx_enrollments.where(:effective_on => cobra_begin_date).first
          expect(cobra_enrollment).to be_present
        end

        it 'should create new valid benefit group assignment' do
          assignment = census_employee.benefit_group_assignments.where(start_on: cobra_begin_date).first
          expect(assignment).to be_present
        end
      end
    end
  end

  describe "#is_terminate_possible" do
    let(:params) { valid_params.merge(:aasm_state => aasm_state) }
    let(:census_employee) { CensusEmployee.new(**params) }

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"employment_terminated"}

      it "should return false" do
        expect(census_employee.is_terminate_possible?).to be_falsey
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"eligible"}

      it "should return true" do
        expect(census_employee.is_terminate_possible?).to be_truthy
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"cobra_eligible"}

      it "should return true" do
        expect(census_employee.is_terminate_possible?).to be_truthy
      end
    end

    context "if censue employee is cobra linked" do
      let(:aasm_state) {"cobra_linked"}

      it "should return true" do
        expect(census_employee.is_terminate_possible?).to be_truthy
      end
    end

    context "if censue employee is newly designatede linked" do
      let(:aasm_state) {"newly_designated_linked"}

      it "should return true" do
        expect(census_employee.is_terminate_possible?).to be_truthy
      end
    end
  end

  describe "#terminate_employee_enrollments", dbclean: :around_each do
    let(:aasm_state) { :imported }
    include_context "setup renewal application"

    let(:renewal_effective_date) { TimeKeeper.date_of_record.beginning_of_month - 2.months }
    let(:predecessor_state) { :expired }
    let(:renewal_state) { :active }
    let(:renewal_benefit_group) { renewal_application.benefit_packages.first}
    let(:census_employee) do
      ce = create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: organization.active_benefit_sponsorship
      )
      person = create(:person, last_name: ce.last_name, first_name: ce.first_name)
      employee_role = build(:benefit_sponsors_employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
      ce.update_attributes({employee_role: employee_role})
      Family.find_or_build_from_employee_role(employee_role)
      ce
    end

    let!(:active_bga) {  create(:benefit_sponsors_benefit_group_assignment, benefit_group: renewal_benefit_group, census_employee: census_employee) }
    let!(:inactive_bga) {  create(:benefit_sponsors_benefit_group_assignment, benefit_group: current_benefit_package, census_employee: census_employee) }

    let!(:active_enrollment) do
      create(
        :hbx_enrollment,
        household: census_employee.employee_role.person.primary_family.active_household,
        coverage_kind: "health",
        kind: "employer_sponsored",
        effective_on: renewal_benefit_group.start_on,
        benefit_sponsorship_id: benefit_sponsorship.id,
        sponsored_benefit_package_id: renewal_benefit_group.id,
        employee_role_id: census_employee.employee_role.id,
        benefit_group_assignment_id: active_bga.id,
        aasm_state: "coverage_selected"
      )
    end

    let!(:expired_enrollment) do
      create(
        :hbx_enrollment,
        household: census_employee.employee_role.person.primary_family.active_household,
        coverage_kind: "health",
        kind: "employer_sponsored",
        effective_on: current_benefit_package.start_on,
        benefit_sponsorship_id: benefit_sponsorship.id,
        sponsored_benefit_package_id: current_benefit_package.id,
        employee_role_id: census_employee.employee_role.id,
        benefit_group_assignment_id: inactive_bga.id,
        aasm_state: "coverage_expired"
      )
    end

    context "when EE termination date falls under expired application" do
      before do
        employment_terminated_on = (TimeKeeper.date_of_record - 3.months).end_of_month
        census_employee.employment_terminated_on = employment_terminated_on
        census_employee.coverage_terminated_on = employment_terminated_on
        census_employee.aasm_state = "employment_terminated"
        census_employee.save
        census_employee.terminate_employee_enrollments(employment_terminated_on)
        expired_enrollment.reload
        active_enrollment.reload
      end

      it "should terminate, expired enrollment with terminated date = ee coverage termination date" do

        expect(expired_enrollment.aasm_state).to eq "coverage_terminated"
        expect(expired_enrollment.terminated_on).to eq (TimeKeeper.date_of_record.last_month.end_of_month - 2.months).end_of_month
      end

      it "should cancel active coverage" do
        expect(active_enrollment.aasm_state).to eq "coverage_canceled"
      end
    end

    context "when EE termination date falls under active application" do
      let(:employment_terminated_on) { TimeKeeper.date_of_record.end_of_month }

      before do
        census_employee.employment_terminated_on = employment_terminated_on
        census_employee.coverage_terminated_on = TimeKeeper.date_of_record.end_of_month
        census_employee.aasm_state = "employment_terminated"
        census_employee.save
        census_employee.terminate_employee_enrollments(employment_terminated_on)
        expired_enrollment.reload
        active_enrollment.reload
      end

      it "shouldn't update expired enrollment" do
        expect(expired_enrollment.aasm_state).to eq "coverage_expired"
      end

      it "should termiante active coverage" do
        expect(active_enrollment.aasm_state).to eq "coverage_termination_pending"
      end

      it "should cancel future active coverage" do
        active_enrollment.effective_on = TimeKeeper.date_of_record.next_month
        active_enrollment.save
        census_employee.terminate_employee_enrollments(employment_terminated_on)
        active_enrollment.reload
        expect(active_enrollment.aasm_state).to eq "coverage_canceled"
      end
    end
  end

  describe "#assign_benefit_package" do

    let(:current_effective_date) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
    let(:effective_period)       { current_effective_date..(current_effective_date.next_year.prev_day) }

    context "when previous benefit package assignment not present" do
      let!(:census_employee) do
        ce = create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile)
        ce.benefit_group_assignments.delete_all
        ce
      end

      context "when benefit package and start_on date passed" do

        it "should create assignments" do
          expect(census_employee.benefit_group_assignments.blank?).to be_truthy
          census_employee.assign_benefit_package(current_benefit_package, current_benefit_package.start_on)
          expect(census_employee.benefit_group_assignments.count).to eq 1
          assignment = census_employee.benefit_group_assignments.first
          expect(assignment.start_on).to eq current_benefit_package.start_on
          expect(assignment.end_on).to eq current_benefit_package.end_on
        end
      end

      context "when benefit package passed and start_on date nil" do

        it "should create assignment with current date as start date" do
          expect(census_employee.benefit_group_assignments.blank?).to be_truthy
          census_employee.assign_benefit_package(current_benefit_package)
          expect(census_employee.benefit_group_assignments.count).to eq 1
          assignment = census_employee.benefit_group_assignments.first
          expect(assignment.start_on).to eq TimeKeeper.date_of_record
          expect(assignment.end_on).to eq current_benefit_package.end_on
        end
      end
    end

    context "when previous benefit package assignment present" do
      let!(:census_employee)     { create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile) }
      let!(:new_benefit_package) { initial_application.benefit_packages.create({title: 'Second Benefit Package', probation_period_kind: :first_of_month})}

      context "when new benefit package and start_on date passed" do

        it "should create new assignment and cancel existing assignment" do
          expect(census_employee.benefit_group_assignments.present?).to be_truthy
          census_employee.assign_benefit_package(new_benefit_package, new_benefit_package.start_on)
          expect(census_employee.benefit_group_assignments.count).to eq 2

          prev_assignment = census_employee.benefit_group_assignments.first
          expect(prev_assignment.start_on).to eq current_benefit_package.start_on
          expect(prev_assignment.end_on).to eq current_benefit_package.start_on

          new_assignment = census_employee.benefit_group_assignments.last
          expect(new_assignment.start_on).to eq new_benefit_package.start_on
          # We are creating BGAs with start date and end date by default
          expect(new_assignment.end_on).to eq new_benefit_package.end_on
        end
      end

      context "when new benefit package passed and start_on date nil" do

        it "should create new assignment and term existing assignment with an end date" do
          expect(census_employee.benefit_group_assignments.present?).to be_truthy
          census_employee.assign_benefit_package(new_benefit_package)
          expect(census_employee.benefit_group_assignments.count).to eq 2

          prev_assignment = census_employee.benefit_group_assignments.first
          expect(prev_assignment.start_on).to eq current_benefit_package.start_on
          expect(prev_assignment.end_on).to eq TimeKeeper.date_of_record.prev_day

          new_assignment = census_employee.benefit_group_assignments.last
          expect(new_assignment.start_on).to eq TimeKeeper.date_of_record
          # We are creating BGAs with start date and end date by default
          expect(new_assignment.end_on).to eq new_benefit_package.end_on
        end
      end
    end
  end
end
