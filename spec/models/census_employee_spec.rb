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

  describe "Model instance" do
    context "model Attributes" do
      it {is_expected.to have_field(:benefit_sponsors_employer_profile_id).of_type(BSON::ObjectId)}
      it {is_expected.to have_field(:expected_selection).of_type(String).with_default_value_of("enroll")}
      it {is_expected.to have_field(:hired_on).of_type(Date)}
    end

    context "Associations" do
      it {is_expected.to embed_many(:benefit_group_assignments)}
      it {is_expected.to embed_many(:census_dependents)}
      it {is_expected.to belong_to(:benefit_sponsorship)}
    end

    context "Validations" do
      subject { described_class.new }
      it {is_expected.to validate_presence_of(:ssn)}

      it "validates presence of benefit_sponsors_employer_profile_id when employer_profile_id is blank" do
        allow(subject).to receive(:employer_profile_id).and_return(nil)
        is_expected.to validate_presence_of(:benefit_sponsors_employer_profile_id)
      end

      it "validates presence of employer_profile_id when benefit_sponsors_employer_profile_id is blank" do
        allow(subject).to receive(:benefit_sponsors_employer_profile_id).and_return(nil)
        is_expected.to validate_presence_of(:employer_profile_id)
      end
    end

    context "index" do
      it {is_expected.to have_index_for(aasm_state: 1)}
      it {is_expected.to have_index_for(encrypted_ssn: 1, dob: 1, aasm_state: 1)}
    end
  end


  describe "Model initialization" do
    context "with no arguments" do
      let(:params) {{}}

      it "should not save" do
        expect(CensusEmployee.create(**params).valid?).to be_falsey
      end
    end

    context "with no employer profile" do
      let(:params) {valid_params.except(:employer_profile, :benefit_sponsorship)}

      it "should fail validation" do
        expect(CensusEmployee.create(**params).errors[:employer_profile_id].any?).to be_truthy
      end
    end

    context "with no ssn" do
      let(:params) {valid_params.except(:ssn)}

      it "should fail validation" do
        expect(CensusEmployee.create(**params).errors[:ssn].any?).to be_truthy
      end
    end

    context "validates expected_selection" do
      let(:params_expected_selection) {valid_params.merge(expected_selection: "enroll")}
      let(:params_in_valid) {valid_params.merge(expected_selection: "rspec-mock")}

      it "should have a valid value" do
        expect(CensusEmployee.create(**params_expected_selection).valid?).to be_truthy
      end

      it "should have a valid value" do
        expect(CensusEmployee.create(**params_in_valid).valid?).to be_falsey
      end
    end

    context "with no dob" do
      let(:params) {valid_params.except(:dob)}

      it "should fail validation" do
        expect(CensusEmployee.create(**params).errors[:dob].any?).to be_truthy
      end
    end

    context "with no hired_on" do
      let(:params) {valid_params.except(:hired_on)}

      it "should fail validation" do
        expect(CensusEmployee.create(**params).errors[:hired_on].any?).to be_truthy
      end
    end

    context "with no is owner" do
      let(:params) {valid_params.merge({:is_business_owner => nil})}

      it "should fail validation" do
        expect(CensusEmployee.create(**params).errors[:is_business_owner].any?).to be_truthy
      end
    end

    context "with all required attributes" do
      let(:params) {valid_params}
      let(:initial_census_employee) {CensusEmployee.new(**params)}

      it "should be valid" do
        expect(initial_census_employee.valid?).to be_truthy
      end

      it "should save" do
        expect(initial_census_employee.save).to be_truthy
      end

      it "should be findable by ID" do
        initial_census_employee.save
        expect(CensusEmployee.find(initial_census_employee.id)).to eq initial_census_employee
      end

      it "in an unlinked state" do
        expect(initial_census_employee.eligible?).to be_truthy
      end

      it "and should have the correct associated employer profile" do
        expect(initial_census_employee.employer_profile._id).to eq initial_census_employee.benefit_sponsors_employer_profile_id
      end

      it "should be findable by employer profile" do
        initial_census_employee.save
        expect(CensusEmployee.find_all_by_employer_profile(employer_profile).size).to eq 1
        expect(CensusEmployee.find_all_by_employer_profile(employer_profile).first).to eq initial_census_employee
      end
    end
  end

  describe "Censusdependents validators" do
    let(:params) {valid_params}
    let(:initial_census_employee) {CensusEmployee.new(**params)}
    let(:dependent) {CensusDependent.new(first_name: 'David', last_name: 'Henry', ssn: "", employee_relationship: "spouse", dob: TimeKeeper.date_of_record - 30.years, gender: "male")}
    let(:dependent2) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: 333_333_333, dob: TimeKeeper.date_of_record - 30.years, gender: "male")}

    it "allow dependent ssn's to be updated to nil" do
      initial_census_employee.census_dependents = [dependent]
      initial_census_employee.save!
      expect(initial_census_employee.census_dependents.first.ssn).to match(nil)
    end

    it "ignores dependent ssn's if ssn not nil" do
      initial_census_employee.census_dependents = [dependent2]
      initial_census_employee.save!
      expect(initial_census_employee.census_dependents.first.ssn).to match("333333333")
    end

    context "with duplicate ssn's on dependents" do
      let(:child1) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: 333_333_333)}
      let(:child2) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: 333_333_333)}

      it "should have errors" do
        initial_census_employee.census_dependents = [child1, child2]
        expect(initial_census_employee.save).to be_falsey
        expect(initial_census_employee.errors[:base].first).to match(/SSN's must be unique for each dependent and subscriber/)
      end
    end

    context "with duplicate blank ssn's on dependents" do
      let(:child1) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: "")}
      let(:child2) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: "")}

      it "should not have errors" do
        initial_census_employee.census_dependents = [child1, child2]
        expect(initial_census_employee.valid?).to be_truthy
      end
    end

    context "with ssn matching subscribers" do
      let(:child1) {FactoryBot.build(:census_dependent, employee_relationship: "child_under_26", ssn: initial_census_employee.ssn)}

      it "should have errors" do
        initial_census_employee.census_dependents = [child1]
        expect(initial_census_employee.save).to be_falsey
        expect(initial_census_employee.errors[:base].first).to match(/SSN's must be unique for each dependent and subscriber/)
      end
    end


    context "and census employee identifying info is edited" do
      before {initial_census_employee.ssn = "606060606"}

      it "should be be valid" do
        expect(initial_census_employee.valid?).to be_truthy
      end
    end
  end

  describe "Cobrahire date checkers" do
    let(:params) {valid_params}
    let(:initial_census_employee) {CensusEmployee.new(**params)}
    context "check_cobra_begin_date" do
      it "should not have errors when existing_cobra is false" do
        initial_census_employee.cobra_begin_date = initial_census_employee.hired_on - 5.days
        initial_census_employee.existing_cobra = false
        expect(initial_census_employee.save).to be_truthy
      end

      context "when existing_cobra is true" do
        before do
          initial_census_employee.existing_cobra = 'true'
        end

        it "should not have errors when hired_on earlier than cobra_begin_date" do
          initial_census_employee.cobra_begin_date = initial_census_employee.hired_on + 5.days
          expect(initial_census_employee.save).to be_truthy
        end

        it "should have errors when hired_on later than cobra_begin_date" do
          initial_census_employee.cobra_begin_date = initial_census_employee.hired_on - 5.days
          expect(initial_census_employee.save).to be_falsey
          expect(initial_census_employee.errors[:cobra_begin_date].to_s).to match(/must be after Hire Date/)
        end
      end
    end
  end

  describe "Employee terminated" do
    let(:params) {valid_params}
    let(:initial_census_employee) { CensusEmployee.new(**params) }
    context "and employee is terminated and reported by employer on timely basis" do

      let(:termination_maximum) { Settings.aca.shop_market.retroactive_coverage_termination_maximum.to_hash }
      let(:earliest_retro_coverage_termination_date) {TimeKeeper.date_of_record.advance(termination_maximum).end_of_month }
      let(:earliest_valid_employment_termination_date) {earliest_retro_coverage_termination_date.beginning_of_month}
      let(:invalid_employment_termination_date) {earliest_valid_employment_termination_date - 1.day}
      let(:invalid_coverage_termination_date) {invalid_employment_termination_date.end_of_month}


      context "and the employment termination is reported later after max retroactive date" do

        before {initial_census_employee.terminate_employment!(invalid_employment_termination_date)}

        it "calculated coverage termination date should preceed the valid coverage termination date" do
          expect(invalid_coverage_termination_date).to be < earliest_retro_coverage_termination_date
        end

        it "is in terminated state" do
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employment_terminated"
        end

        it "should have the correct employment termination date" do
          expect(CensusEmployee.find(initial_census_employee.id).employment_terminated_on).to eq invalid_employment_termination_date
        end

        it "should have the earliest coverage termination date" do
          expect(CensusEmployee.find(initial_census_employee.id).coverage_terminated_on).to eq earliest_retro_coverage_termination_date
        end

        context "and the user is HBX admin" do
          it "should use cancancan to permit admin termination"
        end
      end

      context "and the termination date is in the future" do
        before {initial_census_employee.terminate_employment!(TimeKeeper.date_of_record + 10.days)}
        it "is in termination pending state" do
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employee_termination_pending"
        end
      end

      context ".terminate_future_scheduled_census_employees" do
        it "should terminate the census employee on the day of the termination date" do
          initial_census_employee.update_attributes(employment_terminated_on: TimeKeeper.date_of_record + 2.days, aasm_state: "employee_termination_pending")
          CensusEmployee.terminate_future_scheduled_census_employees(TimeKeeper.date_of_record + 2.days)
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employment_terminated"
        end

        it "should not terminate the census employee if today's date < termination date" do
          initial_census_employee.update_attributes(employment_terminated_on: TimeKeeper.date_of_record + 2.days, aasm_state: "employee_termination_pending")
          CensusEmployee.terminate_future_scheduled_census_employees(TimeKeeper.date_of_record + 1.days)
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employee_termination_pending"
        end

        it "should return the existing state of the census employee if today's date > termination date" do
          initial_census_employee.save
          initial_census_employee.update_attributes(employment_terminated_on: TimeKeeper.date_of_record + 2.days, aasm_state: "employment_terminated")
          CensusEmployee.terminate_future_scheduled_census_employees(TimeKeeper.date_of_record + 3.days)
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employment_terminated"
        end

        it "should also terminate the census employees if termination date is in the past" do
          initial_census_employee.update_attributes(employment_terminated_on: TimeKeeper.date_of_record - 3.days, aasm_state: "employee_termination_pending")
          CensusEmployee.terminate_future_scheduled_census_employees(TimeKeeper.date_of_record)
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employment_terminated"
        end
      end

      context "and the termination date is within the retroactive reporting time period" do
        before {initial_census_employee.terminate_employment!(earliest_valid_employment_termination_date)}

        it "is in terminated state" do
          expect(CensusEmployee.find(initial_census_employee.id).aasm_state).to eq "employment_terminated"
        end

        it "should have the correct employment termination date" do
          expect(CensusEmployee.find(initial_census_employee.id).employment_terminated_on).to eq earliest_valid_employment_termination_date
        end

        it "should have the earliest coverage termination date" do
          expect(CensusEmployee.find(initial_census_employee.id).coverage_terminated_on).to eq earliest_retro_coverage_termination_date
        end


        context "and the terminated employee is rehired" do
          let!(:rehire) {initial_census_employee.replicate_for_rehire}

          it "rehired census employee instance should have same demographic info" do
            expect(rehire.first_name).to eq initial_census_employee.first_name
            expect(rehire.last_name).to eq initial_census_employee.last_name
            expect(rehire.gender).to eq initial_census_employee.gender
            expect(rehire.ssn).to eq initial_census_employee.ssn
            expect(rehire.dob).to eq initial_census_employee.dob
            expect(rehire.employer_profile).to eq initial_census_employee.employer_profile
          end

          it "rehired census employee instance should be initialized state" do
            expect(rehire.eligible?).to be_truthy
            expect(rehire.hired_on).to_not eq initial_census_employee.hired_on
            expect(rehire.active_benefit_group_assignment.present?).to be_falsey
            expect(rehire.employee_role.present?).to be_falsey
          end

          it "the previously terminated census employee should be in rehired state" do
            expect(initial_census_employee.aasm_state).to eq "rehired"
          end
        end

        context "and the COBRA terminated employee is rehired" do

          before do
            initial_census_employee.update_for_cobra(hired_on.next_day)
            initial_census_employee.terminate_employee_role!
          end

          let!(:cobra_rehire) { initial_census_employee.replicate_for_rehire }

          it "rehired census employee instance should have same demographic info" do
            expect(cobra_rehire.first_name).to eq initial_census_employee.first_name
            expect(cobra_rehire.last_name).to eq initial_census_employee.last_name
            expect(cobra_rehire.gender).to eq initial_census_employee.gender
            expect(cobra_rehire.ssn).to eq initial_census_employee.ssn
            expect(cobra_rehire.dob).to eq initial_census_employee.dob
            expect(cobra_rehire.employer_profile).to eq initial_census_employee.employer_profile
          end

          it "rehired census employee instance should be initialized state" do
            expect(cobra_rehire.eligible?).to be_truthy
            expect(cobra_rehire.hired_on).to_not eq initial_census_employee.hired_on
            expect(cobra_rehire.active_benefit_group_assignment.present?).to be_falsey
            expect(cobra_rehire.employee_role.present?).to be_falsey
          end

          it "the previously terminated census employee should be in rehired state" do
            expect(initial_census_employee.aasm_state).to eq "rehired"
          end

          context 'when rehired within the past 2 months' do

            let!(:rehire_cobra_employee) do
              cobra_rehire.hired_on = TimeKeeper.date_of_record - 50.days
              cobra_rehire.save
              cobra_rehire
            end

            it 'should be able to shop based on new hire rules' do
              expect(rehire_cobra_employee.new_hire_enrollment_period.cover?(TimeKeeper.date_of_record)).to be_truthy
            end
          end
        end
      end
    end
  end

  describe "When Employee Role" do
    let(:params) {valid_params}
    let(:initial_census_employee) {CensusEmployee.new(**params)}

    context "and a benefit group isn't yet assigned to employee" do
      it "the roster instance should not be ready for linking" do
        initial_census_employee.benefit_group_assignments.delete_all
        expect(initial_census_employee.may_link_employee_role?).to be_falsey
      end
    end

    context "and a benefit group is assigned to employee" do
      let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: initial_census_employee)}

      before do
        initial_census_employee.benefit_group_assignments = [benefit_group_assignment]
        initial_census_employee.save
      end

      it "the employee census record should be ready for linking" do
        expect(initial_census_employee.may_link_employee_role?).to be_truthy
      end
    end

    context "and the benefit group plan year isn't published" do
      it "the roster instance should not be ready for linking" do
        benefit_application.cancel! if benefit_application.may_cancel?
        expect(initial_census_employee.may_link_employee_role?).to be_falsey
      end
    end
  end

  describe "When plan year is published" do
    let(:params) { valid_params }
    let(:initial_census_employee) {CensusEmployee.new(**params)}
    let(:benefit_group_assignment) {FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_group, census_employee: initial_census_employee)}

    context "and a roster match by SSN and DOB is performed" do

      before do
        initial_census_employee.benefit_group_assignments = [benefit_group_assignment]
        initial_census_employee.save
      end

      context "using non-matching ssn and dob" do
        let(:invalid_employee_role) {FactoryBot.build(:benefit_sponsors_employee_role, ssn: "777777777", dob: TimeKeeper.date_of_record - 5.days, employer_profile: employer_profile)}

        it "should return an empty array" do
          expect(CensusEmployee.matchable(invalid_employee_role.ssn, invalid_employee_role.dob)).to eq []
        end
      end

      context "using matching ssn and dob" do
        let(:valid_employee_role) {FactoryBot.build(:benefit_sponsors_employee_role, ssn: initial_census_employee.ssn, dob: initial_census_employee.dob, employer_profile: employer_profile)}
        let!(:user) {FactoryBot.create(:user, person: valid_employee_role.person)}

        it "should return the roster instance" do
          expect(CensusEmployee.matchable(valid_employee_role.ssn, valid_employee_role.dob).collect(&:id)).to eq [initial_census_employee.id]
        end

        context "and a link employee role request is received" do
          context "and the provided employee role identifying information doesn't match a census employee" do
            let(:invalid_employee_role) {FactoryBot.build(:benefit_sponsors_employee_role, ssn: "777777777", dob: TimeKeeper.date_of_record - 5.days, employer_profile: employer_profile)}

            it "should raise an error" do
              initial_census_employee.employee_role = invalid_employee_role
              expect(initial_census_employee.employee_role_linked?).to be_falsey
            end
          end

          context "and the provided employee role identifying information does match a census employee" do
            before do
              initial_census_employee.employee_role = valid_employee_role
            end

            it "should link the roster instance and employer role" do
              expect(initial_census_employee.employee_role_linked?).to be_truthy
            end

            context "and it is saved" do
              before {initial_census_employee.save}

              it "should no longer be available for linking" do
                expect(initial_census_employee.may_link_employee_role?).to be_falsey
              end

              it "should be findable by employee role" do
                expect(CensusEmployee.find_all_by_employee_role(valid_employee_role).size).to eq 1
                expect(CensusEmployee.find_all_by_employee_role(valid_employee_role).first).to eq initial_census_employee
              end

              it "and should be delinkable" do
                expect(initial_census_employee.may_delink_employee_role?).to be_truthy
              end

              it "should have a published benefit group" do
                expect(initial_census_employee.published_benefit_group).to eq benefit_group
              end
            end
          end
        end
      end
    end

    context 'When there are two active benefit applications' do
      let(:current_year) { TimeKeeper.date_of_record.year }
      let(:effective_period) {current_effective_date..current_effective_date.next_year.prev_day}
      let(:open_enrollment_period) {effective_period.min.prev_month..(effective_period.min - 10.days)}
      let!(:service_areas2) {benefit_sponsorship.service_areas_on(effective_period.min)}
      let!(:benefit_sponsor_catalog2) {benefit_sponsorship.benefit_sponsor_catalog_for(effective_period.min)}
      let(:initial_application2) do
        ben_app = BenefitSponsors::BenefitApplications::BenefitApplication.new(
          benefit_sponsor_catalog: benefit_sponsor_catalog2,
          open_enrollment_period: open_enrollment_period,
          aasm_state: :active,
          recorded_rating_area: rating_area,
          recorded_service_areas: service_areas2,
          fte_count: 5,
          pte_count: 0,
          msp_count: 0
        )
        ben_app.benefit_application_items.build(effective_period: effective_period, sequence_id: 1, state: :active)
        ben_app
      end
      let!(:product_package2) {initial_application2.benefit_sponsor_catalog.product_packages.detect {|package| package.package_kind == :single_issuer}}
      let!(:current_benefit_package2) {build(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, product_package: product_package2, title: "second benefit package", benefit_application: initial_application2)}

      before do
        FactoryBot.create(:benefit_sponsors_benefit_group_assignment, benefit_group: current_benefit_package2, census_employee: initial_census_employee)
        initial_application2.benefit_packages = [current_benefit_package2]
        benefit_sponsorship.benefit_applications = [initial_application2]
        benefit_sponsorship.save!
        initial_census_employee.save
      end

      it 'should only pick active benefit group assignment - first benefit package' do
        initial_census_employee.benefit_group_assignments[0].update_attributes(is_active: false, created_at: Date.new(current_year, 2, 21))
        initial_census_employee.benefit_group_assignments[1].update_attributes(is_active: true, created_at: Date.new(current_year - 1, 2, 21))
        expect(initial_census_employee.published_benefit_group.title).to eq 'first benefit package'
      end

      it 'should pick latest benefit group assignment if all the assignments are inactive' do
        initial_census_employee.benefit_group_assignments[0].update_attributes(is_active: false, created_at: Date.new(current_year, 2, 21))
        initial_census_employee.benefit_group_assignments[1].update_attributes(is_active: false, created_at: Date.new(current_year - 1, 2, 21))
        expect(initial_census_employee.published_benefit_group.title).to eq 'second benefit package'
      end

      it 'should only pick active benefit group assignment - second benefit package' do
        initial_census_employee.benefit_group_assignments[0].update_attributes(is_active: true, created_at: Date.new(current_year, 2, 21))
        initial_census_employee.benefit_group_assignments[1].update_attributes(is_active: false, created_at: Date.new(current_year - 1, 2, 21))
        expect(initial_census_employee.published_benefit_group.title).to eq 'second benefit package'
      end
    end
  end

  context "multiple employers have active, terminated and rehired employees", dbclean: :around_each do
    let(:today) {TimeKeeper.date_of_record}
    let(:one_month_ago) {today - 1.month}
    let(:last_month) {one_month_ago.beginning_of_month..one_month_ago.end_of_month}
    let(:last_year_to_date) {(today - 1.year)..today}

    let(:er1_active_employee_count) {2}
    let(:er1_terminated_employee_count) {1}
    let(:er1_rehired_employee_count) {1}

    let(:er2_active_employee_count) {1}
    let(:er2_terminated_employee_count) {1}

    let(:employee_count) do
      er1_active_employee_count +
        er1_terminated_employee_count +
        er1_rehired_employee_count +
        er2_active_employee_count +
        er2_terminated_employee_count
    end

    let(:terminated_today_employee_count) {2}
    let(:terminated_last_month_employee_count) {1}
    let(:er1_termination_count) {er1_terminated_employee_count + er1_rehired_employee_count}

    let(:terminated_employee_count) {er1_terminated_employee_count + er2_terminated_employee_count}
    let(:termed_status_employee_count) {terminated_employee_count + er1_rehired_employee_count}

    let(:employer_count) {2} # We're only creating 2 ER profiles

    let(:employer_profile_1) {initial_application.benefit_sponsorship.profile}
    let(:organization1) {employer_profile_1.organization}

    let(:aasm_state) {:active}
    let(:package_kind) {:single_issuer}
    let(:effective_period) {current_effective_date..current_effective_date.next_year.prev_day}
    let(:open_enrollment_period) {effective_period.min.prev_month..(effective_period.min - 10.days)}
    let!(:employer_profile_2) {FactoryBot.create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site, site: organization.site)}
    let(:organization2) {employer_profile_2.organization}
    let!(:benefit_sponsorship2) do
      sponsorship = employer_profile_2.add_benefit_sponsorship
      sponsorship.save
      sponsorship
    end
    let!(:service_areas2) {benefit_sponsorship2.service_areas_on(effective_period.min)}
    let(:benefit_sponsor_catalog2) {benefit_sponsorship2.benefit_sponsor_catalog_for(effective_period.min)}
    let(:initial_application2) do
      ben_app = BenefitSponsors::BenefitApplications::BenefitApplication.new(
        benefit_sponsor_catalog: benefit_sponsor_catalog2,
        open_enrollment_period: open_enrollment_period,
        aasm_state: aasm_state,
        recorded_rating_area: rating_area,
        recorded_service_areas: service_areas2,
        fte_count: 5,
        pte_count: 0,
        msp_count: 0
      )
      ben_app.benefit_application_items.build(effective_period: effective_period, sequence_id: 1, state: aasm_state)
      ben_app
    end

    let(:product_package2) {initial_application.benefit_sponsor_catalog.product_packages.detect {|package| package.package_kind == package_kind}}
    let(:current_benefit_package2) {build(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, product_package: product_package2, benefit_application: initial_application2)}


    let(:er1_active_employees) do
      FactoryBot.create_list(:census_employee, er1_active_employee_count,
                             employer_profile: employer_profile_1, benefit_sponsorship: organization1.active_benefit_sponsorship)
    end
    let(:er1_terminated_employees) do
      FactoryBot.create_list(:census_employee, er1_terminated_employee_count,
                             employer_profile: employer_profile_1, benefit_sponsorship: organization1.active_benefit_sponsorship)
    end
    let(:er1_rehired_employees) do
      FactoryBot.create_list(:census_employee, er1_rehired_employee_count,
                             employer_profile: employer_profile_1, benefit_sponsorship: organization1.active_benefit_sponsorship)
    end
    let(:er2_active_employees) do
      FactoryBot.create_list(:census_employee, er2_active_employee_count,
                             employer_profile: employer_profile_2, benefit_sponsorship: organization2.active_benefit_sponsorship)
    end
    let(:er2_terminated_employees) do
      FactoryBot.create_list(:census_employee, er2_terminated_employee_count,
                             employer_profile: employer_profile_2, benefit_sponsorship: organization2.active_benefit_sponsorship)
    end

    before do

      initial_application2.benefit_packages = [current_benefit_package2]
      benefit_sponsorship2.benefit_applications = [initial_application2]
      benefit_sponsorship2.save!

      er1_active_employees.each do |ee|
        ee.aasm_state = "employee_role_linked"
        ee.save!
      end

      er1_terminated_employees.each do |ee|
        ee.aasm_state = "employment_terminated"
        ee.employment_terminated_on = today
        ee.save!
      end

      er1_rehired_employees.each do |ee|
        ee.aasm_state = "rehired"
        ee.employment_terminated_on = today
        ee.save!
      end

      er2_active_employees.each do |ee|
        ee.aasm_state = "employee_role_linked"
        ee.save!
      end

      er2_terminated_employees.each do |ee|
        ee.aasm_state = "employment_terminated"
        ee.employment_terminated_on = one_month_ago
        ee.save!
      end
    end

    it "should find all employers" do
      expect(BenefitSponsors::Organizations::Organization.all.employer_profiles.size).to eq employer_count
    end

    it "should find all employees" do
      expect(CensusEmployee.all.size).to eq employee_count
    end

    context "and terminated employees are queried with no passed parameters" do
      it "should find the all employees terminated today" do
        expect(CensusEmployee.find_all_terminated.size).to eq terminated_today_employee_count
      end
    end

    context "and terminated employees who were terminated one month ago are queried" do
      it "should find the correct set" do
        expect(CensusEmployee.find_all_terminated(date_range: last_month).size).to eq terminated_last_month_employee_count
      end
    end

    context "and for one employer, the set of employees terminated since company joined the exchange are queried" do
      it "should find the correct set" do
        expect(CensusEmployee.find_all_terminated(employer_profiles: [employer_profile_1],
                                                  date_range: last_year_to_date).size).to eq er1_termination_count
      end
    end

  end

end
