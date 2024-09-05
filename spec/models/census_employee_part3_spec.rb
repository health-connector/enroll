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
      Family.find_or_build_from_employee_role(employee_role)
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
      Family.find_or_build_from_employee_role(employee_role)
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

end
