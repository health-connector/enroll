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

  context "a census employee is added in the database" do

    let!(:existing_census_employee) do
      FactoryBot.create(:benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: employer_profile.active_benefit_sponsorship)
    end

    let!(:person) do
      Person.create(
        first_name: existing_census_employee.first_name,
        last_name: existing_census_employee.last_name,
        ssn: existing_census_employee.ssn,
        dob: existing_census_employee.dob,
        gender: existing_census_employee.gender
      )
    end
    let!(:user) {create(:user, person: person)}
    let!(:employee_role) do
      EmployeeRole.create(
        person: person,
        hired_on: existing_census_employee.hired_on,
        employer_profile: existing_census_employee.employer_profile
      )
    end

    it "existing record should be findable" do
      expect(CensusEmployee.find(existing_census_employee.id)).to be_truthy
    end

    context "and a new census employee instance, with same ssn same employer profile is built" do
      let!(:duplicate_census_employee) {existing_census_employee.dup}

      it "should have same identifying info" do
        expect(duplicate_census_employee.ssn).to eq existing_census_employee.ssn
        expect(duplicate_census_employee.employer_profile_id).to eq existing_census_employee.employer_profile_id
      end

      context "and existing census employee is in eligible status" do
        it "existing record should be eligible status" do
          expect(CensusEmployee.find(existing_census_employee.id).aasm_state).to eq "eligible"
        end

        it "new instance should fail validation" do
          expect(duplicate_census_employee.valid?).to be_falsey
          expect(duplicate_census_employee.errors[:base].first).to match(/Employee with this identifying information is already active/)
        end

        context "and assign existing census employee to benefit group" do
          let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: existing_census_employee)}

          let!(:saved_census_employee) do
            ee = CensusEmployee.find(existing_census_employee.id)
            ee.benefit_group_assignments = [benefit_group_assignment]
            ee.save
            ee
          end

          context "and publish the plan year and associate census employee with employee_role" do
            before do
              saved_census_employee.employee_role = employee_role
              saved_census_employee.save
            end

            it "existing census employee should be employee_role_linked status" do
              expect(CensusEmployee.find(saved_census_employee.id).aasm_state).to eq "employee_role_linked"
            end

            it "new cenesus employee instance should fail validation" do
              expect(duplicate_census_employee.valid?).to be_falsey
              expect(duplicate_census_employee.errors[:base].first).to match(/Employee with this identifying information is already active/)
            end

            context "and existing employee instance is terminated" do
              before do
                saved_census_employee.terminate_employment(TimeKeeper.date_of_record - 1.day)
                saved_census_employee.save
              end

              it "should be in terminated state" do
                expect(saved_census_employee.aasm_state).to eq "employment_terminated"
              end

              it "new instance should save" do
                expect(duplicate_census_employee.save!).to be_truthy
              end
            end

            context "and the roster census employee instance is in any state besides unlinked" do
              let(:employee_role_linked_state) {saved_census_employee.dup}
              let(:employment_terminated_state) {saved_census_employee.dup}
              before do
                employee_role_linked_state.aasm_state = :employee_role_linked
                employment_terminated_state.aasm_state = :employment_terminated
              end

              it "should prevent linking with another employee role" do
                expect(employee_role_linked_state.may_link_employee_role?).to be_falsey
                expect(employment_terminated_state.may_link_employee_role?).to be_falsey
              end
            end
          end
        end

      end
    end
  end

  context "validation for employment_terminated_on" do
    let(:census_employee) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship, hired_on: TimeKeeper.date_of_record.beginning_of_year - 50.days)}

    it "should fail when terminated date before than hired date" do
      census_employee.employment_terminated_on = census_employee.hired_on - 10.days
      expect(census_employee.valid?).to be_falsey
      expect(census_employee.errors[:employment_terminated_on].any?).to be_truthy
    end

    it "should fail when terminated date not within 60 days" do
      census_employee.employment_terminated_on = TimeKeeper.date_of_record - 75.days
      expect(census_employee.valid?).to be_falsey
      expect(census_employee.errors[:employment_terminated_on].any?).to be_truthy
    end

    it "should success" do
      census_employee.employment_terminated_on = TimeKeeper.date_of_record - 1.day
      expect(census_employee.valid?).to be_truthy
      expect(census_employee.errors[:employment_terminated_on].any?).to be_falsey
    end
  end

  context "validation for census_dependents_relationship" do
    let(:census_employee) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship)}
    let(:spouse1) {FactoryBot.build(:census_dependent, employee_relationship: "spouse")}
    let(:spouse2) {FactoryBot.build(:census_dependent, employee_relationship: "spouse")}
    let(:partner1) {FactoryBot.build(:census_dependent, employee_relationship: "domestic_partner")}
    let(:partner2) {FactoryBot.build(:census_dependent, employee_relationship: "domestic_partner")}

    it "should fail when have tow spouse" do
      allow(census_employee).to receive(:census_dependents).and_return([spouse1, spouse2])
      expect(census_employee.valid?).to be_falsey
      expect(census_employee.errors[:census_dependents].any?).to be_truthy
    end

    it "should fail when have tow domestic_partner" do
      allow(census_employee).to receive(:census_dependents).and_return([partner2, partner1])
      expect(census_employee.valid?).to be_falsey
      expect(census_employee.errors[:census_dependents].any?).to be_truthy
    end

    it "should fail when have one spouse and one domestic_partner" do
      allow(census_employee).to receive(:census_dependents).and_return([spouse1, partner1])
      expect(census_employee.valid?).to be_falsey
      expect(census_employee.errors[:census_dependents].any?).to be_truthy
    end

    it "should success when have no dependents" do
      allow(census_employee).to receive(:census_dependents).and_return([])
      expect(census_employee.errors[:census_dependents].any?).to be_falsey
    end

    it "should success" do
      allow(census_employee).to receive(:census_dependents).and_return([partner1])
      expect(census_employee.errors[:census_dependents].any?).to be_falsey
    end
  end

  context "scope employee_name" do
    let(:census_employee1) do
      FactoryBot.create(:benefit_sponsors_census_employee,
                        benefit_sponsorship: employer_profile.active_benefit_sponsorship,
                        employer_profile: employer_profile,
                        first_name: "Amy",
                        last_name: "Frank")
    end

    let(:census_employee2) do
      FactoryBot.create(:benefit_sponsors_census_employee,
                        benefit_sponsorship: employer_profile.active_benefit_sponsorship,
                        employer_profile: employer_profile,
                        first_name: "Javert",
                        last_name: "Burton")
    end

    let(:census_employee3) do
      FactoryBot.create(:benefit_sponsors_census_employee,
                        benefit_sponsorship: employer_profile.active_benefit_sponsorship,
                        employer_profile: employer_profile,
                        first_name: "Burt",
                        last_name: "Love")
    end

    before :each do
      CensusEmployee.delete_all
      census_employee1
      census_employee2
      census_employee3
    end

    it "search by first_name" do
      expect(CensusEmployee.employee_name("Javert")).to eq [census_employee2]
    end

    it "search by last_name" do
      expect(CensusEmployee.employee_name("Frank")).to eq [census_employee1]
    end

    it "search by full_name" do
      expect(CensusEmployee.employee_name("Amy Frank")).to eq [census_employee1]
    end

    it "search by part of name" do
      expect(CensusEmployee.employee_name("Bur").count).to eq 2
      expect(CensusEmployee.employee_name("Bur")).to include census_employee2
      expect(CensusEmployee.employee_name("Bur")).to include census_employee3
    end
  end

  context "update_hbx_enrollment_effective_on_by_hired_on" do

    let(:employee_role) {FactoryBot.create(:benefit_sponsors_employee_role, employer_profile: employer_profile)}
    let(:census_employee) do
      FactoryBot.create(:benefit_sponsors_census_employee,
                        benefit_sponsorship: employer_profile.active_benefit_sponsorship,
                        employer_profile: employer_profile,
                        employee_role_id: employee_role.id)
    end

    let(:person) {double}
    let(:family) {double(id: '1', active_household: double(hbx_enrollments: double(shop_market: double(enrolled_and_renewing: double(open_enrollments: [@enrollment])))))}

    let(:benefit_group) {double}

    before :all do
      family = FactoryBot.create(:family, :with_primary_family_member)
      @enrollment = FactoryBot.create(:hbx_enrollment, household: family.active_household)
    end

    it "should update employee_role hired_on" do
      census_employee.update(hired_on: TimeKeeper.date_of_record + 10.days)
      employee_role.reload
      expect(employee_role.hired_on).to eq TimeKeeper.date_of_record + 10.days
    end

    it "should update hbx_enrollment effective_on" do
      allow(census_employee).to receive(:employee_role).and_return(employee_role)
      allow(employee_role).to receive(:person).and_return(person)
      allow(person).to receive(:primary_family).and_return(family)
      allow(@enrollment).to receive(:effective_on).and_return(TimeKeeper.date_of_record - 10.days)
      allow(@enrollment).to receive(:benefit_group).and_return(benefit_group)
      allow(benefit_group).to receive(:effective_on_for).and_return(TimeKeeper.date_of_record + 20.days)

      census_employee.update(hired_on: TimeKeeper.date_of_record + 10.days)
      expect(@enrollment.read_attribute(:effective_on)).to eq TimeKeeper.date_of_record + 20.days
    end
  end

  # @todo fix; has this ever worked ?
  # context "Employee is migrated into Enroll database without an EmployeeRole" do
  #   let(:person) {}
  #   let(:family) {}
  #   let(:employer_profile) {}
  #   let(:plan_year) {}
  #   let(:hbx_enrollment) {}
  #   let(:benefit_group_assignment) {}

  #   context "and the employee links to roster" do

  #     it "should create an employee_role"
  #   end

  #   context "and the employee is terminated" do

  #     it "should create an employee_role"
  #   end
  end

  describe 'scopes' do
    context ".covered" do
      let(:site)                  { build(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:benefit_sponsor)        {  create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile_initial_application, site: site) }
      let(:benefit_sponsorship)    { benefit_sponsor.active_benefit_sponsorship }
      let(:employer_profile)      {  benefit_sponsorship.profile }
      let!(:benefit_package) { benefit_sponsorship.benefit_applications.first.benefit_packages.first}
      let(:census_employee_for_scope_testing)   { FactoryBot.create(:census_employee, employer_profile: employer_profile) }
      let(:household) { FactoryBot.create(:household, family: family)}
      let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
      let!(:benefit_group_assignment) do
        FactoryBot.create(
          :benefit_sponsors_benefit_group_assignment,
          benefit_group: benefit_package,
          census_employee: census_employee_for_scope_testing,
          start_on: benefit_package.start_on,
          end_on: benefit_package.end_on,
          hbx_enrollment_id: enrollment.id
        )
      end
      let!(:enrollment) do
        FactoryBot.create(:hbx_enrollment, household: household, aasm_state: 'coverage_selected', sponsored_benefit_package_id: benefit_package.id)
      end

      it "should return covered employees" do
        expect(CensusEmployee.covered).to include(census_employee_for_scope_testing)
      end
    end

    context 'by_benefit_package_and_assignment_on_or_later' do
      include_context "setup employees"
      before do
        date = TimeKeeper.date_of_record.beginning_of_month
        bga = census_employees.first.benefit_group_assignments.first
        bga.assign_attributes(start_on: date + 1.month)
        bga.save(validate: false)
        bga2 = census_employees.second.benefit_group_assignments.first
        bga2.assign_attributes(start_on: date - 1.month)
        bga2.save(validate: false)

        @census_employees = CensusEmployee.by_benefit_package_and_assignment_on_or_later(initial_application.benefit_packages.first, date)
      end

      it "should return more than one" do
        expect(@census_employees.count).to eq 4
      end

      it 'Should include CE' do
        [census_employees.first.id, census_employees[3].id, census_employees[4].id].each do |ce_id|
          expect(@census_employees.pluck(:id)).to include(ce_id)
        end
      end

      it 'should not include CE' do
        [census_employees[1].id].each do |ce_id|
          expect(@census_employees.pluck(:id)).not_to include(ce_id)
        end
      end
    end
  end

  describe 'construct_employee_role' do
    let(:user)  { FactoryBot.create(:user) }
    context 'when employee_role present' do
      let(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, employer_profile: employer_profile) }
      let(:census_employee) do
        FactoryBot.create :benefit_sponsors_census_employee, employer_profile: employer_profile,
                                                             benefit_sponsorship: organization.active_benefit_sponsorship,
                                                             employee_role_id: employee_role.id
      end
      before do
        person = employee_role.person
        person.user = user
        person.save
        census_employee.construct_employee_role
        census_employee.reload
      end
      it "should return true when link_employee_role!" do
        expect(census_employee.aasm_state).to eq('employee_role_linked')
      end
    end

    context 'when employee_role not present' do
      let(:census_employee) do
        FactoryBot.create :benefit_sponsors_census_employee, employer_profile: employer_profile,
                                                             benefit_sponsorship: organization.active_benefit_sponsorship
      end
      before do
        census_employee.construct_employee_role
        census_employee.reload
      end
      it { expect(census_employee.aasm_state).to eq('eligible') }
    end
  end

  context "construct_employee_role_for_match_person" do
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship
    end

    let(:person) do
      FactoryBot.create(:person,
                        first_name: census_employee.first_name,
                        last_name: census_employee.last_name,
                        dob: census_employee.dob,
                        ssn: census_employee.ssn,
                        gender: census_employee.gender)
    end
    let(:census_employee1) {FactoryBot.build(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: organization.active_benefit_sponsorship)}
    let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee1)}


    it "should return false when not match person" do
      expect(census_employee1.construct_employee_role_for_match_person).to eq false
    end

    it "should return false when match person which has active employee role for current census employee" do
      census_employee.update_attributes(benefit_sponsors_employer_profile_id: employer_profile.id)
      person.employee_roles.create!(ssn: census_employee.ssn,
                                    benefit_sponsors_employer_profile_id: census_employee.employer_profile.id,
                                    census_employee_id: census_employee.id,
                                    hired_on: census_employee.hired_on)
      expect(census_employee.construct_employee_role_for_match_person).to eq false
    end

    it "should return true when match person has no active employee roles for current census employee" do
      person.employee_roles.create!(ssn: census_employee.ssn,
                                    benefit_sponsors_employer_profile_id: census_employee.employer_profile.id,
                                    hired_on: census_employee.hired_on)
      expect(census_employee.construct_employee_role_for_match_person).to eq true
    end

    it "should send email notification for non conversion employee" do
      allow(census_employee1).to receive(:active_benefit_group_assignment).and_return benefit_group_assignment
      person.employee_roles.create!(ssn: census_employee1.ssn,
                                    employer_profile_id: census_employee1.employer_profile.id,
                                    hired_on: census_employee1.hired_on)
      expect(census_employee1.send_invite!).to eq true
    end
  end

  context "newhire_enrollment_eligible" do
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship
    end

    let(:benefit_group_assignment) {create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee)}

    it "should return true when active_benefit_group_assignment is initialized" do
      allow(census_employee).to receive(:active_benefit_group_assignment).and_return benefit_group_assignment
      expect(census_employee.newhire_enrollment_eligible?).to eq true
    end

    it "should return false when active_benefit_group_assignment is not initialized" do
      allow(census_employee).to receive(:active_benefit_group_assignment).and_return nil
      expect(census_employee.newhire_enrollment_eligible?).to eq false
    end
  end

  context "generate_and_deliver_checkbook_url" do
    let(:census_employee) do
      FactoryBot.create :benefit_sponsors_census_employee,
                        employer_profile: employer_profile,
                        benefit_sponsorship: organization.active_benefit_sponsorship
    end

    let(:hbx_enrollment) {HbxEnrollment.new(coverage_kind: 'health')}
    let(:plan) {FactoryBot.create(:plan)}
    let(:builder_class) {"ShopEmployerNotices::OutOfPocketNotice"}
    let(:builder) {instance_double(builder_class, :deliver => true)}
    let(:notice_triggers) {double("notice_triggers")}
    let(:notice_trigger) {instance_double("NoticeTrigger", :notice_template => "template", :mpi_indicator => "mpi_indicator")}

    before do
      allow(employer_profile).to receive(:plan_years).and_return([benefit_application])
      allow(census_employee).to receive(:employer_profile).and_return(employer_profile)
      allow(census_employee).to receive_message_chain(:employer_profile, :plan_years).and_return([benefit_application])
      allow(census_employee).to receive_message_chain(:active_benefit_group, :reference_plan).and_return(plan)
      allow(notice_triggers).to receive(:first).and_return(notice_trigger)
      allow(notice_trigger).to receive_message_chain(:notice_builder, :classify).and_return(builder_class)
      allow(notice_trigger).to receive_message_chain(:notice_builder, :safe_constantize, :new).and_return(builder)
      allow(notice_trigger).to receive_message_chain(:notice_trigger_element_group, :notice_peferences).and_return({})
      allow(ApplicationEventKind).to receive_message_chain(:where, :first).and_return(double("ApplicationEventKind", {:notice_triggers => notice_triggers, :title => "title", :event_name => "OutOfPocketNotice"}))
      allow_any_instance_of(Services::CheckbookServices::PlanComparision).to receive(:generate_url).and_return("fake_url")
    end
    context "#generate_and_deliver_checkbook_url" do
      it "should create a builder and deliver without expection" do
        expect {census_employee.generate_and_deliver_checkbook_url}.not_to raise_error
      end

      it 'should trigger deliver' do
        expect(builder).to receive(:deliver)
        census_employee.generate_and_deliver_checkbook_url
      end
    end

    context "#generate_and_save_to_temp_folder " do
      it "should builder and save without expection" do
        expect {census_employee.generate_and_save_to_temp_folder}.not_to raise_error
      end

      it 'should not trigger deliver' do
        expect(builder).not_to receive(:deliver)
        census_employee.generate_and_save_to_temp_folder
      end
    end
  end

  context "terminating census employee on the roster & actions on existing enrollments", dbclean: :after_each do

    context "change the aasm state & populates terminated on of enrollments" do

      let(:census_employee) do
        FactoryBot.create :benefit_sponsors_census_employee,
                          employer_profile: employer_profile,
                          benefit_sponsorship: organization.active_benefit_sponsorship
      end

      let(:employee_role) {FactoryBot.create(:benefit_sponsors_employee_role, employer_profile: employer_profile)}
      let(:family) {FactoryBot.create(:family, :with_primary_family_member)}

      let(:hbx_enrollment) {FactoryBot.create(:hbx_enrollment, sponsored_benefit_package_id: benefit_group.id, household: family.active_household, coverage_kind: 'health', employee_role_id: employee_role.id)}
      let(:hbx_enrollment_two) {FactoryBot.create(:hbx_enrollment, sponsored_benefit_package_id: benefit_group.id, household: family.active_household, coverage_kind: 'dental', employee_role_id: employee_role.id)}
      let(:hbx_enrollment_three) {FactoryBot.create(:hbx_enrollment, sponsored_benefit_package_id: benefit_group.id, household: family.active_household, aasm_state: 'renewing_waived', employee_role_id: employee_role.id)}
      let(:assignment) {double("BenefitGroupAssignment", benefit_package: benefit_group)}

      before do
        allow(census_employee).to receive(:active_benefit_group_assignment).and_return(assignment)
        allow(HbxEnrollment).to receive(:find_enrollments_by_benefit_group_assignment).and_return([hbx_enrollment, hbx_enrollment_two, hbx_enrollment_three], [])
        census_employee.update_attributes(employee_role_id: employee_role.id)
      end

      termination_dates = [TimeKeeper.date_of_record - 5.days, TimeKeeper.date_of_record, TimeKeeper.date_of_record + 5.days]
      termination_dates.each do |terminated_on|

        context 'move the enrollment into proper state' do

          before do
            # we do not want to trigger notice
            # takes too much time on processing
            allow_any_instance_of(BenefitSponsors::ModelEvents::HbxEnrollment).to receive(:notify_on_save).and_return(nil)
            census_employee.terminate_employment!(terminated_on)
          end

          it "should move the health enrollment to pending/terminated status" do
            coverage_end = census_employee.earliest_coverage_termination_on(terminated_on)
            if coverage_end < TimeKeeper.date_of_record
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_terminated'
            else
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_termination_pending'
            end
          end

          it "should set the coverage termination on date on the health enrollment" do
            expect(hbx_enrollment.reload.terminated_on).to eq census_employee.earliest_coverage_termination_on(terminated_on)
          end

          it "should move the dental enrollment to pending/terminated status" do
            coverage_end = census_employee.earliest_coverage_termination_on(terminated_on)
            if coverage_end < TimeKeeper.date_of_record
              expect(hbx_enrollment_two.reload.aasm_state).to eq 'coverage_terminated'
            else
              expect(hbx_enrollment_two.reload.aasm_state).to eq 'coverage_termination_pending'
            end
          end
        end

        context 'move the enrollment aasm state to cancel status' do

          before do
            hbx_enrollment.update_attribute(:effective_on, TimeKeeper.date_of_record.next_month)
            hbx_enrollment_two.update_attribute(:effective_on, TimeKeeper.date_of_record.next_month)
            # we do not want to trigger notice
            # takes too much time on processing
            allow_any_instance_of(BenefitSponsors::ModelEvents::HbxEnrollment).to receive(:notify_on_save).and_return(nil)
            census_employee.terminate_employment!(terminated_on)
          end

          it "should cancel the health enrollment if effective date is in future" do
            if census_employee.coverage_terminated_on < hbx_enrollment.effective_on
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_canceled'
            else
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_termination_pending'
            end
          end

          it "should set the coverage termination on date on the health enrollment" do
            if census_employee.coverage_terminated_on < hbx_enrollment.effective_on
              expect(hbx_enrollment.reload.terminated_on).to eq nil
            else
              expect(hbx_enrollment.reload.terminated_on).to eq census_employee.coverage_terminated_on
            end
          end

          it "should cancel the dental enrollment if effective date is in future" do
            if census_employee.coverage_terminated_on < hbx_enrollment.effective_on
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_canceled'
            else
              expect(hbx_enrollment.reload.aasm_state).to eq 'coverage_termination_pending'
            end
          end

          it "should set the coverage termination on date on the dental enrollment" do
            if census_employee.coverage_terminated_on < hbx_enrollment.effective_on
              expect(hbx_enrollment_two.reload.terminated_on).to eq nil
            else
              expect(hbx_enrollment.reload.terminated_on).to eq census_employee.coverage_terminated_on
            end
          end
        end

        context 'move to enrollment aasm state to inactive state' do

          before do
            # we do not want to trigger notice
            # takes too much time on processing
            allow_any_instance_of(BenefitSponsors::ModelEvents::HbxEnrollment).to receive(:notify_on_save).and_return(nil)
            census_employee.terminate_employment!(terminated_on)
          end

          it "should move the waived enrollment to inactive state" do
            expect(hbx_enrollment_three.reload.aasm_state).to eq 'inactive' if terminated_on >= TimeKeeper.date_of_record
          end

          it "should set the coverage termination on date on the dental enrollment" do
            expect(hbx_enrollment_three.reload.terminated_on).to eq nil
          end
        end
      end
    end
  end

  context '.new_hire_enrollment_period' do

    let(:census_employee) {CensusEmployee.new(**valid_params)}
    let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee)}

    before do
      census_employee.benefit_group_assignments = [benefit_group_assignment]
      census_employee.save!
      benefit_group.plan_year.update_attributes(:aasm_state => 'published')
    end

    context 'when hired_on date is in the past' do
      it 'should return census employee created date as new hire enrollment period start date' do
        # created_at will have default utc time zone
        time_zone = TimeKeeper.date_according_to_exchange_at(census_employee.created_at).beginning_of_day
        expect(census_employee.new_hire_enrollment_period.min).to eq(time_zone)
      end
    end

    context 'when hired_on date is in the future' do
      let(:hired_on) {TimeKeeper.date_of_record + 14.days}

      it 'should return hired_on date as new hire enrollment period start date' do
        expect(census_employee.new_hire_enrollment_period.min).to eq census_employee.hired_on
      end
    end

    # @todo fix; this is broken too
    # context 'when earliest effective date is in future more than 30 days from current date' do
    #   let(:hired_on) {TimeKeeper.date_of_record}

    #   it 'should return earliest_eligible_date as new hire enrollment period end date' do
    #     # TODO: - Fix Effective On For & Eligible On on benefit package
    #     expected_end_date = (hired_on + 60.days)
    #     expected_end_date = (hired_on + 60.days).end_of_month + 1.day if expected_end_date.day != 1
    #     # expect(census_employee.new_hire_enrollment_period.max).to eq (expected_end_date).end_of_day
    #   end
    # end

    context 'when earliest effective date less than 30 days from current date' do

      it 'should return 30 days from new hire enrollment period start as end date' do
        expect(census_employee.new_hire_enrollment_period.max).to eq (census_employee.new_hire_enrollment_period.min + 30.days).end_of_day
      end
    end
  end

  # @todo fix; this is broken
  # context '.earliest_eligible_date' do
  #   let(:hired_on) {TimeKeeper.date_of_record}

  #   let(:census_employee) {CensusEmployee.new(**valid_params)}
  #   let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: census_employee)}

  #   before do
  #     census_employee.benefit_group_assignments = [benefit_group_assignment]
  #     census_employee.save!
  #     # benefit_group.plan_year.update_attributes(:aasm_state => 'published')
  #   end

  #   it 'should return earliest effective date' do
  #     # TODO: - Fix Effective On For & Eligible On on benefit package
  #     eligible_date = (hired_on + 60.days)
  #     eligible_date = (hired_on + 60.days).end_of_month + 1.day if eligible_date.day != 1
  #     # expect(census_employee.earliest_eligible_date).to eq eligible_date
  #   end
  # end

  context 'Validating CensusEmployee Termination Date' do
    let(:census_employee) {CensusEmployee.new(**valid_params)}

    it 'should return true when census employee is not terminated' do
      expect(census_employee.valid?).to be_truthy
    end

    it 'should return false when census employee date is not within 60 days' do
      census_employee.hired_on = TimeKeeper.date_of_record - 120.days
      census_employee.employment_terminated_on = TimeKeeper.date_of_record - 90.days
      expect(census_employee.valid?).to be_falsey
    end

    it 'should return true when census employee is already terminated' do
      census_employee.hired_on = TimeKeeper.date_of_record - 120.days
      census_employee.save! # set initial state
      census_employee.aasm_state = "employment_terminated"
      census_employee.employment_terminated_on = TimeKeeper.date_of_record - 90.days
      expect(census_employee.valid?).to be_truthy
    end
  end

  context '.benefit_group_assignment_by_package' do
    include_context "setup renewal application"

    let(:census_employee) do
      create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: benefit_sponsorship
      )
    end
    let(:benefit_group_assignment1) do
      create(
        :benefit_group_assignment,
        benefit_group: renewal_application.benefit_packages.first,
        census_employee: census_employee,
        start_on: renewal_application.benefit_packages.first.start_on,
        end_on: renewal_application.benefit_packages.first.end_on
      )
    end

    before :each do
      census_employee.benefit_group_assignments.destroy_all
    end

    it "should return the first benefit group assignment by benefit package id and active start on date" do
      benefit_group_assignment1
      expect(census_employee.benefit_group_assignment_by_package(benefit_group_assignment1.benefit_package_id, benefit_group_assignment1.start_on)).to eq(benefit_group_assignment1)
    end

    it "should return nil if no benefit group assignments match criteria" do
      expect(
        census_employee.benefit_group_assignment_by_package(benefit_group_assignment1.benefit_package_id, benefit_group_assignment1.start_on + 1.year)
      ).to eq(nil)
    end
  end

  context '.assign_default_benefit_package' do
    include_context "setup renewal application"

    let(:census_employee) do
      create(
        :benefit_sponsors_census_employee,
        employer_profile: employer_profile,
        benefit_sponsorship: benefit_sponsorship
      )
    end

    let!(:benefit_group_assignment1) do
      FactoryBot.create(
        :benefit_group_assignment,
        benefit_group: renewal_application.benefit_packages.first,
        census_employee: census_employee,
        start_on: renewal_application.benefit_packages.first.start_on,
        end_on: renewal_application.benefit_packages.first.end_on
      )
    end

    it 'should have active benefit group assignment' do
      expect(census_employee.active_benefit_group_assignment.present?).to be_truthy
      expect(census_employee.active_benefit_group_assignment.benefit_package).to eq benefit_sponsorship.active_benefit_application.benefit_packages.first
    end

    it 'should have renewal benefit group assignment' do
      renewal_application.update_attributes(predecessor_id: benefit_application.id)
      benefit_sponsorship.benefit_applications << renewal_application
      expect(census_employee.renewal_benefit_group_assignment.present?).to be_truthy
      expect(census_employee.renewal_benefit_group_assignment.benefit_package).to eq benefit_sponsorship.renewal_benefit_application.benefit_packages.first
    end

    it 'should have most recent renewal benefit group assignment' do
      renewal_application.update_attributes(predecessor_id: benefit_application.id)
      benefit_sponsorship.benefit_applications << renewal_application
      benefit_group_assignment1.update_attributes(created_at: census_employee.benefit_group_assignments.last.created_at + 1.day)
      expect(census_employee.renewal_benefit_group_assignment.created_at).to eq benefit_group_assignment1.created_at
    end
  end

end
