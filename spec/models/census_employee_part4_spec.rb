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
        expected_result = {"$or" => [{"$or" => [{"first_name" => /test1/i}, {"last_name" => /test1/i}]}, {"encrypted_ssn" => "QEVuQwAA0m50gjJW7mR4HLnepJyFmg==\n"}]}
        result = CensusEmployee.search_hash(employee_search)
        expect(result).to eq expected_result
      end

      it "census employee query string for full name" do
        employee_search = "test1 test2"
        expected_result = {"$or" => [{"$and" => [{"first_name" => /test1|test2/i}, {"last_name" => /test1|test2/i}]}, {"encrypted_ssn" => "QEVuQwAA0m50gjJW7mR4HLnepJyFmg==\n"}]}
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
