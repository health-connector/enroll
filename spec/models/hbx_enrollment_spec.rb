# frozen_string_literal: true

require 'rails_helper'
require 'aasm/rspec'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe HbxEnrollment, type: :model, dbclean: :after_each do

  describe HbxEnrollment, dbclean: :around_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    context "an employer defines a plan year with multiple benefit groups, adds employees to roster and assigns benefit groups" do

      before do
        white_collar_benefit_group = build(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, product_package: product_package, benefit_application: initial_application)
        initial_application.benefit_packages << white_collar_benefit_group
        initial_application.save!
      end

      let(:blue_collar_employee_count) {7}
      let(:white_collar_employee_count) {5}
      let(:fte_count) {blue_collar_employee_count + white_collar_employee_count}

      let(:employer_profile) {benefit_sponsorship.profile}
      let(:organization) {employer_profile.organization}

      let(:plan_year) {initial_application}
      let(:blue_collar_benefit_group) {plan_year.benefit_groups[0]}
      let!(:blue_collar_census_employees) { FactoryBot.create_list(:census_employee, blue_collar_employee_count, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship, benefit_group: current_benefit_package)}
      let!(:white_collar_census_employees) {FactoryBot.create_list(:census_employee, white_collar_employee_count, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship, benefit_group: current_benefit_package) }


      it "should have a valid plan year in enrolling state" do
        expect(plan_year.aasm_state).to eq :active
      end

      it "should have a roster with all blue and white collar employees" do
        expect(employer_profile.census_employees.size).to eq fte_count
      end

      context "and employees create employee roles and families" do
        let(:blue_collar_employee_roles) do
          bc_employees = blue_collar_census_employees.collect do |census_employee|
            person = Person.create!(
              first_name: census_employee.first_name,
              last_name: census_employee.last_name,
              ssn: census_employee.ssn,
              dob: census_employee.dob,
              gender: "male"
            )
            employee_role = person.employee_roles.build(
              employer_profile: census_employee.employer_profile,
              census_employee: census_employee,
              hired_on: census_employee.hired_on
            )

            census_employee.employee_role = employee_role
            census_employee.save!
            employee_role
          end
          bc_employees
        end

        let(:white_collar_employee_roles) do
          wc_employees = white_collar_census_employees.collect do |census_employee|
            person = Person.create!(
              first_name: census_employee.first_name,
              last_name: census_employee.last_name,
              ssn: census_employee.ssn,
              # ssn: (census_employee.ssn.to_i + 20).to_s,
              dob: census_employee.dob,
              gender: "male"
            )
            employee_role = person.employee_roles.build(
              employer_profile: census_employee.employer_profile,
              census_employee: census_employee,
              hired_on: census_employee.hired_on
            )

            census_employee.employee_role = employee_role
            census_employee.save!
            employee_role
          end
          wc_employees
        end

        let(:blue_collar_families) do
          blue_collar_employee_roles.reduce([]) do |list, employee_role|
            family = Family.find_or_build_from_employee_role(employee_role)
            list << family
          end
        end

        let(:white_collar_families) do
          white_collar_employee_roles.reduce([]) do |list, employee_role|
            family = Family.find_or_build_from_employee_role(employee_role)
            list << family
          end
        end

        it "should include the requisite blue collar employee roles and families" do
          expect(blue_collar_employee_roles.size).to eq blue_collar_employee_count
          expect(blue_collar_families.size).to eq blue_collar_employee_count
        end

        it "should include the requisite white collar employee roles and families" do
          expect(white_collar_employee_roles.size).to eq white_collar_employee_count
          expect(white_collar_families.size).to eq white_collar_employee_count
        end
      end
    end
  end

  describe HbxEnrollment, dbclean: :after_each do

    include_context "BradyWorkAfterAll"

    before :all do
      create_brady_census_families
    end

    context "is created from an employer_profile, benefit_group, and coverage_household" do
    #   attr_reader :enrollment, :household, :coverage_household
    #   before :all do
    #     @household = mikes_family.households.first
    #     @coverage_household = household.coverage_households.first
    #     @enrollment = household.create_hbx_enrollment_from(
    #         employee_role: mikes_employee_role,
    #         coverage_household: coverage_household,
    #         benefit_group: nil,
    #         benefit_group_assignment: @mikes_census_employee.active_benefit_group_assignment,
    #         benefit_package: @mikes_benefit_group,
    #         sponsored_benefit: @mikes_benefit_group.sponsored_benefits.first
    #     )
    #   end

    #   it "should assign the benefit group assignment" do
    #     expect(enrollment.benefit_group_assignment_id).not_to be_nil
    #   end

    #   it "should be employer sponsored" do
    #     expect(enrollment.kind).to eq "employer_sponsored"
    #   end

    #   it "should set the employer_profile" do
    #     expect(enrollment.employer_profile._id).to eq mikes_employer._id
    #   end

    #   it "should be active" do
    #     expect(enrollment.is_active?).to be_truthy
    #   end

    #   it "should be effective when the plan_year starts by default" do
    #     expect(enrollment.effective_on).to eq mikes_plan_year.start_on
    #   end

    #   it "should be valid" do
    #     expect(enrollment.valid?).to be_truthy
    #   end

    #   it "should default to enrolling everyone" do
    #     expect(enrollment.applicant_ids).to match_array(coverage_household.applicant_ids)
    #   end

    #   it "should not return a total premium" do
    #     expect {enrollment.total_premium}.not_to raise_error
    #   end

    #   it "should not return an employee cost" do
    #     expect {enrollment.total_employee_cost}.not_to raise_error
    #   end

    #   it "should not return an employer contribution" do
    #     expect {enrollment.total_employer_contribution}.not_to raise_error
    #   end

    #   context "and the employee enrolls" do
    #     before :all do
    #       enrollment.plan = enrollment.benefit_group.reference_plan
    #       enrollment.save
    #     end

    #     it "should return a total premium" do
    #       Caches::PlanDetails.load_record_cache!
    #       expect(enrollment.total_premium).to be
    #     end

    #     it "should return an employee cost" do
    #       Caches::PlanDetails.load_record_cache!
    #       expect(enrollment.total_employee_cost).to be
    #     end

    #     it "should return an employer contribution" do
    #       Caches::PlanDetails.load_record_cache!
    #       expect(enrollment.total_employer_contribution).to be
    #     end
    #   end

    #   context "update_current" do
    #     before :all do
    #       @enrollment2 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments
    #       )
    #       @enrollment2.save
    #       @enrollment2.update_current(is_active: false)
    #     end

    #     it "enrollment and enrollment2 should have same household" do
    #       expect(@enrollment2.household).to eq enrollment.household
    #     end

    #     it "enrollment2 should be not active" do
    #       expect(@enrollment2.is_active).to be_falsey
    #     end

    #     it "enrollment should be active" do
    #       expect(enrollment.is_active).to be_truthy
    #     end
    #   end

    #   context "inactive_related_hbxs" do
    #     before :all do
    #       @enrollment3 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments
    #       )
    #       @enrollment3.save
    #       @enrollment3.inactive_related_hbxs
    #     end

    #     it "should have an assigned hbx_id" do
    #       expect(@enrollment3.hbx_id).not_to eq nil
    #     end

    #     it "enrollment and enrollment3 should have same household" do
    #       expect(@enrollment3.household).to eq enrollment.household
    #     end

    #     it "enrollment should be not active" do
    #       expect(enrollment.is_active).to be_falsey
    #     end

    #     it "enrollment3 should be active" do
    #       expect(@enrollment3.is_active).to be_truthy
    #     end

    #     it "should only one active when they have same employer" do
    #       hbxs = @enrollment3.household.hbx_enrollments.select do |hbx|
    #         hbx.employee_role.employer_profile_id == @enrollment3.employee_role.employer_profile_id and hbx.is_active?
    #       end
    #       expect(hbxs.count).to eq 1
    #     end
    #   end

    #   context "waive_coverage_by_benefit_group_assignment" do
    #     before :each do
    #       @enrollment4 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments
    #       )
    #       allow(@enrollment4).to receive(:notify_on_save).and_return true
    #       @enrollment4.save
    #       @enrollment5 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments

    #       )
    #       allow(@enrollment5).to receive(:notify_on_save).and_return true
    #       @enrollment5.save
    #       @enrollment4.waive_coverage_by_benefit_group_assignment("start a new job")
    #       @enrollment5.reload
    #     end

    #     it "enrollment4 should be inactive" do
    #       expect(@enrollment4.aasm_state).to eq "inactive"
    #     end

    #     it "enrollment4 should get waiver_reason" do
    #       expect(@enrollment4.waiver_reason).to eq "start a new job"
    #     end

    #     it "enrollment5 should not be waived" do
    #       expect(@enrollment5.aasm_state).to eq "shopping"
    #     end

    #     it "enrollment5 should not have waiver_reason" do
    #       expect(@enrollment5.waiver_reason).to eq nil
    #     end
    #   end

    #   context "should shedule termination previous auto renewing enrollment" do
    #     before :each do
    #       @enrollment6 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments
    #       )
    #       @enrollment6.effective_on=TimeKeeper.date_of_record + 1.days
    #       @enrollment6.aasm_state = "auto_renewing"
    #       allow(@enrollment6).to receive(:notify_on_save).and_return true
    #       @enrollment6.save
    #       @enrollment7 = household.create_hbx_enrollment_from(
    #           employee_role: mikes_employee_role,
    #           coverage_household: coverage_household,
    #           benefit_group: mikes_benefit_group,
    #           benefit_group_assignment: @mikes_benefit_group_assignments
    #       )
    #       allow(@enrollment7).to receive(:notify_on_save).and_return true
    #       @enrollment7.save
    #       @enrollment7.cancel_previous(TimeKeeper.date_of_record.year)
    #     end

    #     it "doesn't move enrollment for shop market" do
    #       expect(@enrollment6.aasm_state).to eq "auto_renewing"
    #     end

    #     it "should not cancel current shopping enrollment" do
    #       expect(@enrollment7.aasm_state).to eq "shopping"
    #     end
    #   end

    #   context "decorated_elected_plans" do
    #     let(:benefit_package) {BenefitPackage.new}
    #     let(:consumer_role) {FactoryBot.create(:consumer_role)}
    #     let(:person) {double(primary_family: family)}
    #     let(:family) {double}
    #     let(:enrollment) {
    #       enrollment = household.new_hbx_enrollment_from(
    #           consumer_role: consumer_role,
    #           coverage_household: coverage_household,
    #           benefit_package: benefit_package,
    #           qle: true
    #       )
    #       enrollment.save
    #       enrollment
    #     }
    #     let(:hbx_profile) {double}
    #     let(:benefit_sponsorship) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months, renewal_benefit_coverage_period: renewal_bcp, current_benefit_coverage_period: bcp)}
    #     let(:renewal_bcp) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months)}
    #     let(:bcp) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months)}
    #     let(:plan) {FactoryBot.create(:plan)}
    #     let(:plan2) {FactoryBot.create(:plan)}

    #     context "when in open enrollment" do
    #       before :each do
    #         allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
    #         allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
    #         allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(bcp)
    #         allow(consumer_role).to receive(:person).and_return(person)
    #         allow(coverage_household).to receive(:household).and_return household
    #         allow(household).to receive(:family).and_return family
    #         allow(family).to receive(:is_under_special_enrollment_period?).and_return false
    #         allow(family).to receive(:is_under_ivl_open_enrollment?).and_return true
    #         allow(enrollment).to receive(:enrollment_kind).and_return "open_enrollment"
    #       end

    #       it "should return decoratored plans when not in the open enrollment" do
    #         allow(renewal_bcp).to receive(:open_enrollment_contains?).and_return false
    #         allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(bcp)
    #         allow(bcp).to receive(:elected_plans_by_enrollment_members).and_return [plan]
    #         expect(enrollment.decorated_elected_plans('health').first.class).to eq UnassistedPlanCostDecorator
    #         expect(enrollment.decorated_elected_plans('health').count).to eq 1
    #         expect(enrollment.decorated_elected_plans('health').first.id).to eq plan.id
    #       end

    #       it "should return decoratored plans when in the open enrollment" do
    #         allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(renewal_bcp)
    #         allow(renewal_bcp).to receive(:open_enrollment_contains?).and_return true
    #         allow(renewal_bcp).to receive(:elected_plans_by_enrollment_members).and_return [plan2]
    #         expect(enrollment.decorated_elected_plans('health').first.class).to eq UnassistedPlanCostDecorator
    #         expect(enrollment.decorated_elected_plans('health').count).to eq 1
    #         expect(enrollment.decorated_elected_plans('health').first.id).to eq plan2.id
    #       end
    #     end

    #     context "when in special enrollment" do
    #       let(:sep) {SpecialEnrollmentPeriod.new(effective_on: TimeKeeper.date_of_record)}
    #       before :each do
    #         allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
    #         allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
    #         allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(bcp)
    #         allow(consumer_role).to receive(:person).and_return(person)
    #         allow(coverage_household).to receive(:household).and_return household
    #         allow(household).to receive(:family).and_return family
    #         allow(family).to receive(:current_sep).and_return sep
    #         allow(family).to receive(:current_special_enrollment_periods).and_return [sep]
    #         allow(family).to receive(:is_under_special_enrollment_period?).and_return true
    #         allow(enrollment).to receive(:enrollment_kind).and_return "special_enrollment"
    #       end

    #       it "should return decoratored plans when not in the open enrollment" do
    #         enrollment.update_attributes(effective_on: sep.effective_on - 1.month)
    #         allow(renewal_bcp).to receive(:open_enrollment_contains?).and_return false
    #         allow(benefit_sponsorship).to receive(:benefit_coverage_period_by_effective_date).with(enrollment.effective_on).and_return(bcp)
    #         allow(bcp).to receive(:elected_plans_by_enrollment_members).and_return [plan]
    #         expect(enrollment.decorated_elected_plans('health').first.class).to eq UnassistedPlanCostDecorator
    #         expect(enrollment.decorated_elected_plans('health').count).to eq 1
    #         expect(enrollment.decorated_elected_plans('health').first.id).to eq plan.id
    #         expect(enrollment.created_at).not_to be_nil
    #       end
    #     end
    #   end

      context "status_step" do
        let(:hbx_enrollment) {HbxEnrollment.new}

        it "return 1 when coverage_selected" do
          hbx_enrollment.aasm_state = "coverage_selected"
          expect(hbx_enrollment.status_step).to eq 1
        end

        it "return 2 when transmitted_to_carrier" do
          hbx_enrollment.aasm_state = "transmitted_to_carrier"
          expect(hbx_enrollment.status_step).to eq 2
        end

        it "return 3 when enrolled_contingent" do
          hbx_enrollment.aasm_state = "enrolled_contingent"
          expect(hbx_enrollment.status_step).to eq 3
        end

        it "return 4 when coverage_enrolled" do
          hbx_enrollment.aasm_state = "coverage_enrolled"
          expect(hbx_enrollment.status_step).to eq 4
        end

        it "return 5 when coverage_canceled" do
          hbx_enrollment.aasm_state = "coverage_canceled"
          expect(hbx_enrollment.status_step).to eq 5
        end

        it "return 5 when coverage_terminated" do
          hbx_enrollment.aasm_state = "coverage_terminated"
          expect(hbx_enrollment.status_step).to eq 5
        end
      end

      context "enrollment_kind" do
        let(:hbx_enrollment) {HbxEnrollment.new}
        it "should fail validation when blank" do
          hbx_enrollment.enrollment_kind = ""
          expect(hbx_enrollment.valid?).to eq false
          expect(hbx_enrollment.errors[:enrollment_kind].any?).to eq true
        end

        it "should fail validation when not in ENROLLMENT_KINDS" do
          hbx_enrollment.enrollment_kind = "test"
          expect(hbx_enrollment.valid?).to eq false
          expect(hbx_enrollment.errors[:enrollment_kind].any?).to eq true
        end

        it "is_open_enrollment?" do
          hbx_enrollment.enrollment_kind = "open_enrollment"
          expect(hbx_enrollment.is_open_enrollment?).to eq true
          expect(hbx_enrollment.is_special_enrollment?).to eq false
        end

        it "is_special_enrollment?" do
          hbx_enrollment.enrollment_kind = "special_enrollment"
          expect(hbx_enrollment.is_open_enrollment?).to eq false
          expect(hbx_enrollment.is_special_enrollment?).to eq true
        end
      end
    end
  end

  describe HbxProfile, "class methods", type: :model, dbclean: :after_each do

    # before :all do
    #   create_brady_census_families
    # end

    context "#find" do
      it "should return nil with invalid id" do
        expect(HbxEnrollment.find("text")).to eq nil
      end
    end

    context "new_from" do
      include_context "BradyWorkAfterAll"

      attr_reader :household, :coverage_household

      before :all do
        create_brady_coverage_households
        @household = mikes_family.households.first
        @coverage_household = household.coverage_households.first
      end

      let(:benefit_package) {BenefitPackage.new}
      let(:consumer_role) {FactoryBot.create(:consumer_role)}
      let(:person) {double(primary_family: family)}
      let(:family) {@household.family}
      let(:sep) {SpecialEnrollmentPeriod.new(effective_on: TimeKeeper.date_of_record)}
      let(:hbx_profile) {double}
      let(:benefit_sponsorship) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months, renewal_benefit_coverage_period: renewal_bcp, current_benefit_coverage_period: bcp)}
      let(:bcp) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months)}
      let(:renewal_bcp) {double(earliest_effective_date: TimeKeeper.date_of_record - 2.months)}

      before :each do
        allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
        allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
        allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(bcp)
        allow(consumer_role).to receive(:person).and_return(person)
        allow(household).to receive(:family).and_return family
        allow(family).to receive(:is_under_ivl_open_enrollment?).and_return true
        allow(family).to receive(:current_sep).and_return sep
      end

      shared_examples_for "new enrollment from" do |qle, sep, enrollment_period, error|
        context "#{enrollment_period} period" do
          let(:enrollment) {HbxEnrollment.new_from(consumer_role: consumer_role, coverage_household: coverage_household, benefit_package: benefit_package, qle: qle)}
          before do
            allow(family).to receive(:is_under_special_enrollment_period?).and_return sep
            allow(family).to receive(:is_under_ivl_open_enrollment?).and_return enrollment_period == "open_enrollment"
          end

          if error
            it "raises an error" do
              expect {HbxEnrollment.new_from(consumer_role: consumer_role, coverage_household: coverage_household, benefit_package: benefit_package, qle: false)}.to raise_error(RuntimeError)
            end
          else
            it "assigns #{enrollment_period} as enrollment_kind when qle is #{qle}" do
              expect(enrollment.enrollment_kind).to eq enrollment_period
            end

            it "should have submitted at as current date and time" do
              enrollment.save
              expect(enrollment.submitted_at).not_to be_nil
            end

            it "creates hbx_enrollment members " do
              expect(enrollment.hbx_enrollment_members).not_to be_empty
            end

            it "creates members with coverage_start_on as enrollment effective_on" do
              expect(enrollment.hbx_enrollment_members.first.coverage_start_on).to eq enrollment.effective_on
            end
          end
        end
      end

      it_behaves_like "new enrollment from", false, true, "open_enrollment", false
      it_behaves_like "new enrollment from", true, true, "special_enrollment", false
      it_behaves_like "new enrollment from", false, false, "not_open_enrollment", "raise_an_error"
    end

    context "is reporting a qle before the employer plan start_date and having a expired plan year" do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup renewal application"

      let(:predecessor_state)       { :expired }
      let(:renewal_state)           { :active }
      let(:renewal_effective_date)  { TimeKeeper.date_of_record.prev_month.beginning_of_month }

      let(:coverage_household) {double}
      let(:coverage_household_members) {double}
      let(:household) {FactoryBot.create(:household, family: family)}
      let(:qle_kind) {FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date)}

      let(:census_employee) { create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile) }
      let(:employee_role) { FactoryBot.create(:employee_role, person: person, census_employee: census_employee, employer_profile: benefit_sponsorship.profile) }

      let(:person) {FactoryBot.create(:person)}
      let(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
      let(:sep) do
        sep = family.special_enrollment_periods.new
        sep.effective_on_kind = 'date_of_event'
        sep.qualifying_life_event_kind = qle_kind
        sep.qle_on = TimeKeeper.date_of_record - 7.days
        sep.start_on = sep.qle_on
        sep.end_on = sep.qle_on + 30.days
        sep.save
        sep
      end

      before do
        renewal_application
        allow(coverage_household).to receive(:household).and_return family.active_household
        allow(coverage_household).to receive(:coverage_household_members).and_return []
        allow(sep).to receive(:is_active?).and_return true
        allow(family).to receive(:is_under_special_enrollment_period?).and_return true
        expired_py = benefit_sponsorship.benefit_applications.where(aasm_state: 'expired').first

        census_employee.benefit_group_assignments << BenefitGroupAssignment.new(benefit_group: expired_py.benefit_packages[0], start_on: expired_py.start_on)
        census_employee.update_attributes(:employee_role_id => employee_role.id, hired_on: TimeKeeper.date_of_record - 2.months)
        census_employee.update_attribute(:ssn, census_employee.employee_role.person.ssn)
      end

      it "should return a sep with an effective date that equals to sep date" do
        enrollment = HbxEnrollment.new_from(employee_role: employee_role, coverage_household: coverage_household, benefit_group: nil, benefit_package: nil, benefit_group_assignment: nil, qle: true)
        expect(enrollment.effective_on).to eq sep.qle_on
      end
    end

    context "coverage_year" do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:date) {TimeKeeper.date_of_record}
      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }

      let(:sponsored_benefit_package) { initial_application.benefit_packages[0] }
      let(:plan) {Plan.new(active_year: date.year)}
      let(:hbx_enrollment) {HbxEnrollment.new(sponsored_benefit_package_id: sponsored_benefit_package.id, effective_on: current_effective_date, kind: "employer_sponsored", plan: plan)}

      it "should return plan year start on year when shop" do
        expect(hbx_enrollment.coverage_year).to eq current_effective_date.year
      end

      it "should return plan year when ivl" do
        allow(hbx_enrollment).to receive(:kind).and_return("")
        expect(hbx_enrollment.coverage_year).to eq hbx_enrollment.plan.active_year
      end

      it "should return correct year when ivl" do
        allow(hbx_enrollment).to receive(:kind).and_return("")
        allow(hbx_enrollment).to receive(:plan).and_return(nil)
        expect(hbx_enrollment.coverage_year).to eq hbx_enrollment.effective_on.year
      end
    end

    # TODO: - reimplement this spec
    context "calculate_effective_on_from" do
      let(:date) {TimeKeeper.date_of_record}
      let(:family) {double(current_sep: double(effective_on: date), is_under_special_enrollment_period?: true)}
      let(:hbx_profile) {double}
      let(:benefit_sponsorship) {double}
      let(:bcp) {double}
      let(:benefit_group) {double}
      let(:employee_role) {double(hired_on: date)}

      context "shop" do
        it "special_enrollment" do
          expect(HbxEnrollment.calculate_effective_on_from(market_kind: 'shop', qle: true, family: family, employee_role: nil, benefit_group: benefit_group, benefit_sponsorship: nil)).to eq date
        end

        it "open_enrollment" do
          effective_on = date - 10.days
          allow(benefit_group).to receive(:effective_on_for).and_return(effective_on)
          allow(family).to receive(:is_under_special_enrollment_period?).and_return(false)
          expect(HbxEnrollment.calculate_effective_on_from(market_kind: 'shop', qle: false, family: family, employee_role: employee_role, benefit_group: benefit_group, benefit_sponsorship: nil)).to eq effective_on
        end
      end

      context "individual" do
        before :each do
          allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
          allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
          allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(bcp)
        end

        it "special_enrollment" do
          expect(HbxEnrollment.calculate_effective_on_from(market_kind: 'individual', qle: true, family: family, employee_role: nil, benefit_group: nil, benefit_sponsorship: nil)).to eq date
        end

        it "open_enrollment" do
          effective_on = date - 10.days
          allow(bcp).to receive(:earliest_effective_date).and_return effective_on
          allow(family).to receive(:is_under_special_enrollment_period?).and_return(false)
          expect(HbxEnrollment.calculate_effective_on_from(market_kind: 'individual', qle: false, family: family, employee_role: nil, benefit_group: nil, benefit_sponsorship: benefit_sponsorship)).to eq effective_on
        end
      end
    end

    if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
      context "ivl user switching plan from one carrier to other carrier previous hbx_enrollment aasm_sate should be cancel/terminate in DB." do
        let(:person1) {FactoryBot.create(:person, :with_consumer_role)}
        let(:family1) {FactoryBot.create(:family, :with_primary_family_member, :person => person1)}
        let(:household) {FactoryBot.create(:household, family: family1)}
        let(:date) {TimeKeeper.date_of_record}
        let!(:carrier_profile1) {FactoryBot.build(:carrier_profile)}
        let!(:carrier_profile2) {FactoryBot.create(:carrier_profile, organization: organization)}
        let!(:organization) {FactoryBot.create(:organization, legal_name: "CareFirst", dba: "care")}
        let(:plan1) {Plan.new(active_year: date.year, market: "individual", carrier_profile: carrier_profile1)}
        let(:plan2) {Plan.new(active_year: date.year, market: "individual", carrier_profile: carrier_profile2)}

        let(:hbx_enrollment1) do
          HbxEnrollment.new(kind: "individual", plan: plan1, household: family1.latest_household, enrollment_kind: "open_enrollment", aasm_state: 'coverage_selected', consumer_role: person1.consumer_role, enrollment_signature: true)
        end
        let(:hbx_enrollment2) do
          HbxEnrollment.new(kind: "individual", plan: plan2, household: family1.latest_household, enrollment_kind: "open_enrollment", aasm_state: 'shopping', consumer_role: person1.consumer_role, enrollment_signature: true, effective_on: date)
        end

        before do
          TimeKeeper.set_date_of_record_unprotected!(Date.today + 20.days) if TimeKeeper.date_of_record.month == 1 || TimeKeeper.date_of_record.month == 12
        end

        after do
          TimeKeeper.set_date_of_record_unprotected!(Date.today) if TimeKeeper.date_of_record.month == 1 || TimeKeeper.date_of_record.month == 12
        end

        it "should cancel hbx enrollemnt plan1 from carrier1 when choosing plan2 from carrier2" do
          hbx_enrollment1.effective_on = date + 1.day
          hbx_enrollment2.effective_on = date
          # This gets processed on 31st Dec
          if hbx_enrollment1.effective_on.year != hbx_enrollment2.effective_on.year
            hbx_enrollment1.effective_on = date + 2.day
            hbx_enrollment2.effective_on = date + 1.day
          end
          hbx_enrollment2.select_coverage!
          hbx_enrollment1_from_db = HbxEnrollment.by_hbx_id(hbx_enrollment1.hbx_id).first
          expect(hbx_enrollment1_from_db.coverage_canceled?).to be_truthy
          expect(hbx_enrollment2.coverage_selected?).to be_truthy
        end

        it "should not cancel hbx enrollemnt of previous plan year enrollment" do
          hbx_enrollment1.effective_on = date + 1.year
          hbx_enrollment2.effective_on = date
          hbx_enrollment2.select_coverage!
          expect(hbx_enrollment1.coverage_canceled?).to be_falsy
          expect(hbx_enrollment2.coverage_selected?).to be_truthy
        end

        it "should terminate hbx enrollemnt plan1 from carrier1 when choosing hbx enrollemnt plan2 from carrier2" do
          hbx_enrollment1.effective_on = date - 10.days
          hbx_enrollment2.select_coverage!
          hbx_enrollment1_from_db = HbxEnrollment.by_hbx_id(hbx_enrollment1.hbx_id).first
          expect(hbx_enrollment1_from_db.coverage_terminated?).to be_truthy
          expect(hbx_enrollment2.coverage_selected?).to be_truthy
          expect(hbx_enrollment1_from_db.terminated_on).to eq hbx_enrollment2.effective_on - 1.day
        end

        it "terminates previous enrollments if both effective on in the future" do
          hbx_enrollment1.effective_on = date + 10.days
          hbx_enrollment2.effective_on = date + 20.days
          hbx_enrollment2.select_coverage!
          expect(hbx_enrollment1.coverage_terminated?).to be_truthy
          expect(hbx_enrollment2.coverage_selected?).to be_truthy
          expect(hbx_enrollment1.terminated_on).to eq hbx_enrollment2.effective_on - 1.day
        end
      end
    end

    context "can_terminate_coverage?" do
      let(:hbx_enrollment) do
        HbxEnrollment.new(
          kind: 'employer_sponsored',
          aasm_state: 'coverage_selected',
          effective_on: TimeKeeper.date_of_record - 10.days
        )
      end
      it "should return false when may not terminate_coverage" do
        hbx_enrollment.aasm_state = 'inactive'
        expect(hbx_enrollment.can_terminate_coverage?).to eq false
      end

      context "when may_terminate_coverage is true" do
        before :each do
          hbx_enrollment.aasm_state = 'coverage_selected'
        end

        it "should return true" do
          hbx_enrollment.effective_on = TimeKeeper.date_of_record - 10.days
          expect(hbx_enrollment.can_terminate_coverage?).to eq true
        end

        it "should return false" do
          hbx_enrollment.effective_on = TimeKeeper.date_of_record + 10.days
          expect(hbx_enrollment.can_terminate_coverage?).to eq false
        end
      end
    end

    context "cancel_coverage!", dbclean: :after_each do
      let(:family) {FactoryBot.create(:family, :with_primary_family_member)}
      let(:hbx_enrollment) {FactoryBot.create(:hbx_enrollment, household: family.active_household, aasm_state: "inactive")}

      it "should cancel the enrollment" do
        hbx_enrollment.cancel_coverage!
        expect(hbx_enrollment.aasm_state).to eq "coverage_canceled"
      end

      it "should not populate the terminated on" do
        hbx_enrollment.cancel_coverage!
        expect(hbx_enrollment.terminated_on).to eq nil
      end
    end

    context "cancel_for_non_payment!", dbclean: :after_each do
      let(:family) {FactoryBot.create(:family, :with_primary_family_member)}
      let(:hbx_enrollment) {FactoryBot.create(:hbx_enrollment, household: family.active_household, aasm_state: "inactive")}

      it "should cancel the enrollment" do
        hbx_enrollment.cancel_for_non_payment!
        expect(hbx_enrollment.aasm_state).to eq "coverage_canceled"
      end

      it "should not populate the terminated on" do
        hbx_enrollment.cancel_for_non_payment!
        expect(hbx_enrollment.terminated_on).to eq nil
      end
    end


    context "terminate_for_non_payment!", dbclean: :after_each do
      let(:family) {FactoryBot.create(:family, :with_primary_family_member)}
      let(:hbx_enrollment) {FactoryBot.create(:hbx_enrollment, household: family.active_household, aasm_state: "coverage_selected")}

      it "should terminate enrollment" do
        hbx_enrollment.terminate_for_non_payment!
        expect(hbx_enrollment.aasm_state).to eq "coverage_terminated"
      end

      it "should  populate terminate on" do
        hbx_enrollment.terminate_for_non_payment!
        expect(hbx_enrollment.terminated_on).to eq hbx_enrollment.terminated_on
      end
    end
  end

  describe HbxEnrollment, dbclean: :after_each do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    context ".can_select_coverage?" do
      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_on) { current_effective_date }
      let(:hired_on) { TimeKeeper.date_of_record - 3.months }
      let(:employee_created_at) { hired_on }
      let(:employee_updated_at) { employee_created_at }

      let(:person) {FactoryBot.create(:person, first_name: 'John', last_name: 'Smith', dob: '1966-10-10'.to_date, ssn: '123456789')}
      let(:shop_family) {FactoryBot.create(:family, :with_primary_family_member)}

      let(:aasm_state) { :active }
      let(:census_employee) do
        create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, created_at: employee_created_at,
                                                          updated_at: employee_updated_at)
      end
      let(:employee_role) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
      let(:enrollment_kind) { "open_enrollment" }
      let(:special_enrollment_period_id) { nil }
      let(:shop_enrollment) do
        FactoryBot.create(:hbx_enrollment,
                          household: shop_family.latest_household,
                          coverage_kind: "health",
                          effective_on: effective_on,
                          enrollment_kind: enrollment_kind,
                          kind: "employer_sponsored",
                          submitted_at: effective_on - 10.days,
                          benefit_sponsorship_id: benefit_sponsorship.id,
                          sponsored_benefit_package_id: current_benefit_package.id,
                          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                          employee_role_id: employee_role.id,
                          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                          special_enrollment_period_id: special_enrollment_period_id)
      end

      context 'under open enrollment' do
        let(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
        let(:aasm_state) { :enrollment_open }
        let(:hired_on) { TimeKeeper.date_of_record.prev_year }
        let(:open_enrollment_period)  { TimeKeeper.date_of_record..(effective_period.min - 10.days) }

        it "should allow" do
          expect(shop_enrollment.can_select_coverage?).to be_truthy
        end
      end

      context 'outside open enrollment' do
        let(:hired_on) { TimeKeeper.date_of_record.prev_year }

        it "should not allow" do
          expect(shop_enrollment.can_select_coverage?).to be_falsey
        end
      end

      context 'when its a new hire' do
        let(:effective_on) { hired_on.next_month.beginning_of_month }
        let(:hired_on) { TimeKeeper.date_of_record }

        it "should allow" do
          expect(shop_enrollment.can_select_coverage?).to be_truthy
        end
      end

      context 'when not a new hire' do

        it "should not allow" do
          expect(shop_enrollment.can_select_coverage?).to be_falsey
        end

        # TODO: code commented out in hbx_enrollment model. code needs to be enabled before adding this spec back.
        # it "should get a error msg" do
        #   shop_enrollment.can_select_coverage?
        #   expect(shop_enrollment.errors.any?).to be_truthy
        #   expect(shop_enrollment.errors.full_messages.to_s).to match /You can not keep an existing plan which belongs to previous plan year/
        # end
      end

      context 'when roster create present' do
        let(:employee_created_at) { TimeKeeper.date_of_record }

        it "should allow" do
          expect(shop_enrollment.can_select_coverage?).to be_truthy
        end
      end

      context 'when roster update present' do
        let(:employee_updated_at) { TimeKeeper.date_of_record }

        it "should not allow" do
          expect(shop_enrollment.can_select_coverage?).to be_falsey
        end

        # TODO: code commented out in hbx_enrollment model. code needs to be enabled before adding this spec back.
        # it "should get a error msg" do
        #   shop_enrollment.can_select_coverage?
        #   expect(shop_enrollment.errors.any?).to be_truthy
        #   expect(shop_enrollment.errors.full_messages.to_s).to match /You can not keep an existing plan which belongs to previous plan year/
        # end
      end

      context 'with QLE' do
        let(:effective_on) { qle_date.next_month.beginning_of_month }

        let(:qualifying_life_event_kind) {FactoryBot.create(:qualifying_life_event_kind)}
        let(:user) {instance_double("User", :primary_family => test_family, :person => person)}
        let(:qle) {FactoryBot.create(:qualifying_life_event_kind)}
        let(:test_family) {FactoryBot.build(:family, :with_primary_family_member)}
        let(:person) {shop_family.primary_family_member.person}

        let(:special_enrollment_period) do
          special_enrollment = shop_family.special_enrollment_periods.build({
                                                                              qle_on: qle_date,
                                                                              effective_on_kind: "first_of_month"
                                                                            })
          special_enrollment.qualifying_life_event_kind = qualifying_life_event_kind
          special_enrollment.save
          special_enrollment
        end

        let(:enrollment_kind) { "special_enrollment" }
        let(:special_enrollment_period_id) { special_enrollment_period.id }

        before do
          allow(shop_enrollment).to receive(:plan_year_check).with(employee_role).and_return false
        end

        context 'under special enrollment period' do
          let(:qle_date) { TimeKeeper.date_of_record }

          it "should allow" do
            expect(shop_enrollment.can_select_coverage?).to be_truthy
          end
        end

        context 'outside special enrollment period' do
          let(:qle_date) { TimeKeeper.date_of_record - 2.months }

          it "should not allow" do
            expect(shop_enrollment.can_select_coverage?).to be_falsey
          end
        end
      end
    end
  end

  context "Benefits are terminated" do
    let(:effective_on_date) {TimeKeeper.date_of_record.beginning_of_month}
    let!(:hbx_profile) {FactoryBot.create(:hbx_profile)}

    context "Individual benefit" do
      let(:ivl_family) {FactoryBot.create(:family, :with_primary_family_member)}
      let(:ivl_enrollment) do
        ivl_family.latest_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: effective_on_date,
          enrollment_kind: "open_enrollment",
          kind: "individual",
          submitted_at: effective_on_date - 10.days,
          aasm_state: "coverage_selected"
        )
      end
      let(:ivl_termination_date) {TimeKeeper.date_of_record}

      it "should be open enrollment" do
        expect(ivl_enrollment.is_open_enrollment?).to be_truthy
      end

      context "and coverage is terminated" do
        before do
          ivl_enrollment.terminate_benefit(TimeKeeper.date_of_record)
        end

        it "should have terminated date" do
          expect(ivl_enrollment.terminated_on).to eq ivl_termination_date
        end

        it "should be in terminated state" do
          expect(ivl_enrollment.aasm_state).to eq "coverage_terminated"
        end
      end
    end
  end

  describe HbxEnrollment, "given a set of broker accounts", dbclean: :after_each do
    let(:submitted_at) {Time.mktime(2008, 12, 13, 12, 34, 0o0)}
    subject {HbxEnrollment.new(:submitted_at => submitted_at)}
    let(:broker_agency_account_1) {double(:start_on => start_on_1, :end_on => end_on_1)}
    let(:broker_agency_account_2) {double(:start_on => start_on_2, :end_on => end_on_2)}

    describe "with both accounts active before the purchase, and the second one unterminated", dbclean: :after_each do
      let(:start_on_1) {submitted_at - 12.days}
      let(:start_on_2) {submitted_at - 5.days}
      let(:end_on_1) {nil}
      let(:end_on_2) {nil}

      it "should be able to select the applicable broker" do
        expect(subject.select_applicable_broker_account([broker_agency_account_1, broker_agency_account_2])).to eq broker_agency_account_2
      end
    end

    describe "with both accounts active before the purchase, and the later one terminated", dbclean: :after_each do
      let(:start_on_1) {submitted_at - 12.days}
      let(:start_on_2) {submitted_at - 5.days}
      let(:end_on_1) {nil}
      let(:end_on_2) {submitted_at - 2.days}

      it "should have no applicable broker" do
        expect(subject.select_applicable_broker_account([broker_agency_account_1, broker_agency_account_2])).to eq nil
      end
    end

    describe "with one account active before the purchase, and the other active after", dbclean: :after_each do
      let(:start_on_1) {submitted_at - 12.days}
      let(:start_on_2) {submitted_at + 5.days}
      let(:end_on_1) {nil}
      let(:end_on_2) {nil}

      it "should be able to select the applicable broker" do
        expect(subject.select_applicable_broker_account([broker_agency_account_1, broker_agency_account_2])).to eq broker_agency_account_1
      end
    end

    describe "with one account active before the purchase and terminated before the purchase, and the other active after", dbclean: :after_each do
      let(:start_on_1) {submitted_at - 12.days}
      let(:start_on_2) {submitted_at + 5.days}
      let(:end_on_1) {submitted_at - 3.days}
      let(:end_on_2) {nil}

      it "should have no applicable broker" do
        expect(subject.select_applicable_broker_account([broker_agency_account_1, broker_agency_account_2])).to eq nil
      end
    end
  end

  describe HbxEnrollment, "given an enrollment kind of 'special_enrollment'", dbclean: :after_each do
    subject {HbxEnrollment.new({:enrollment_kind => "special_enrollment"})}

    it "should NOT be a shop new hire" do
      expect(subject.new_hire_enrollment_for_shop?).to eq false
    end

    describe "and given a special enrollment period, with a reason of 'birth'", dbclean: :after_each do
      let(:qle_on) {Date.today}

      before :each do
        allow(subject).to receive(:special_enrollment_period).and_return(SpecialEnrollmentPeriod.new(
                                                                           :qualifying_life_event_kind => QualifyingLifeEventKind.new(:reason => "birth"),
                                                                           :qle_on => qle_on
                                                                         ))
      end

      it "should have the eligibility event date of the qle_on" do
        expect(subject.eligibility_event_date).to eq qle_on
      end

      it "should have eligibility_event_kind of 'birth'" do
        expect(subject.eligibility_event_kind).to eq "birth"
      end
    end
  end

  describe HbxEnrollment, "given an enrollment kind of 'open_enrollment'", dbclean: :after_each do
    subject {HbxEnrollment.new({:enrollment_kind => "open_enrollment"})}

    it "should not have an eligibility event date" do
      expect(subject.eligibility_event_has_date?).to eq false
    end

    describe "in the IVL market", dbclean: :after_each do
      before :each do
        subject.kind = "unassisted_qhp"
      end

      it "should not have an eligibility event date" do
        expect(subject.eligibility_event_has_date?).to eq false
      end

      it "should NOT be a shop new hire" do
        expect(subject.new_hire_enrollment_for_shop?).to eq false
      end

      it "should have eligibility_event_kind of 'open_enrollment'" do
        expect(subject.eligibility_event_kind).to eq "open_enrollment"
      end
    end

    describe "in the SHOP market, purchased outside of open enrollment", dbclean: :after_each do

      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:reference_date) { current_effective_date }
      # let(:open_enrollment_start) {reference_date - 15.days}
      # let(:open_enrollment_end) {reference_date - 5.days}

      let(:purchase_time) {Time.now - 20.days}
      let(:hired_on) {reference_date - 21.days}

      before :each do
        subject.kind = "employer_sponsored"
        subject.submitted_at = purchase_time
        subject.benefit_group_assignment = BenefitGroupAssignment.new({
                                                                        :census_employee => CensusEmployee.new({
                                                                                                                 :hired_on => hired_on
                                                                                                               })
                                                                      })

        allow(subject).to receive(:sponsored_benefit_package).and_return(current_benefit_package)
      end

      it "should have an eligibility event date" do
        expect(subject.eligibility_event_has_date?).to eq true
      end

      it "should be a shop new hire" do
        expect(subject.new_hire_enrollment_for_shop?).to eq true
      end

      it "should have eligibility_event_kind of 'new_hire'" do
        expect(subject.eligibility_event_kind).to eq "new_hire"
      end

      it "should have the eligibility event date of hired_on" do
        expect(subject.eligibility_event_date).to eq hired_on
      end
    end

    describe "in the SHOP market, purchased during open enrollment", dbclean: :after_each do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month.prev_month }
      let(:reference_date) { current_effective_date }

      let(:purchase_time) { initial_application.open_enrollment_end_on.prev_day }
      let(:hired_on) {(reference_date - 21.days).to_date}

      before :each do
        subject.kind = "employer_sponsored"
        subject.submitted_at = purchase_time
        subject.benefit_group_assignment = BenefitGroupAssignment.new({
                                                                        :census_employee => CensusEmployee.new({
                                                                                                                 :hired_on => hired_on,
                                                                                                                 :created_at => hired_on
                                                                                                               })
                                                                      })

        allow(subject).to receive(:sponsored_benefit_package).and_return(current_benefit_package)
      end

      describe "when coverage start is the same as the plan year", dbclean: :after_each do
        before(:each) do
          subject.effective_on = reference_date
          subject.submitted_at = purchase_time
        end

        it "should NOT have an eligibility event date" do
          expect(subject.eligibility_event_has_date?).to eq false
        end

        it "should NOT be a shop new hire" do
          expect(subject.new_hire_enrollment_for_shop?).to eq false
        end

        it "should have eligibility_event_kind of 'open_enrollment'" do
          expect(subject.eligibility_event_kind).to eq "open_enrollment"
        end
      end

      describe "when coverage start is the different from the plan year", dbclean: :after_each do
        before(:each) do
          subject.effective_on = reference_date + 12.days
        end

        it "should have an eligibility event date" do
          expect(subject.eligibility_event_has_date?).to eq true
        end

        it "should be a shop new hire" do
          expect(subject.new_hire_enrollment_for_shop?).to eq true
        end

        it "should have eligibility_event_kind of 'new_hire'" do
          expect(subject.eligibility_event_kind).to eq "new_hire"
        end

        it "should have the eligibility event date of hired_on" do
          expect(subject.eligibility_event_date).to eq hired_on
        end
      end
    end
  end

  describe HbxEnrollment, 'dental shop calculation related', type: :model, dbclean: :after_each do
    context ".find_enrollments_by_benefit_group_assignment" do

      let(:enrollment) do
        FactoryBot.create(:hbx_enrollment,
                          household: family.active_household,
                          benefit_group_assignment_id: benefit_group_assignment.id,
                          aasm_state: "coverage_selected",
                          coverage_kind: "health",
                          kind: "employer_sponsored")
      end

      let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
      let(:benefit_group_assignment) { FactoryBot.build(:benefit_group_assignment)}
      let(:subject) { HbxEnrollment.find_enrollments_by_benefit_group_assignment(benefit_group_assignment) }

      it "should return the enrollment with the benefit group assignment" do
        enrollment
        expect(subject).to include enrollment
      end

      it "should be empty if no active coverage" do
        enrollment.update_attributes(aasm_state: "shopping")
        expect(subject).to be_empty
      end

      it "should be empty when no active enrollment with given benefit_group_assignment id" do
        enrollment.update_attributes(aasm_state: "coverage_selected", benefit_group_assignment_id: "")
        expect(subject).to be_empty
      end

      it "should return the dental enrollment" do
        enrollment.update_attributes(coverage_kind: 'dental', aasm_state: 'coverage_selected')
        expect(subject).to include enrollment
      end
    end
  end

  context "A cancelled external enrollment", :dbclean => :after_each do
    let(:family) {FactoryBot.create(:family, :with_primary_family_member)}
    let(:enrollment) do
      FactoryBot.create(:hbx_enrollment,
                        household: family.active_household,
                        kind: "employer_sponsored",
                        submitted_at: TimeKeeper.datetime_of_record - 3.day,
                        created_at: TimeKeeper.datetime_of_record - 3.day)
    end

    before do
      enrollment.aasm_state = "coverage_canceled"
      enrollment.terminated_on = enrollment.effective_on
      enrollment.external_enrollment = true
      enrollment.hbx_enrollment_members.each do |em|
        em.coverage_end_on = em.coverage_start_on
      end
      enrollment.save!
    end

    it "should not be visible to the family" do
      expect(family.enrollments_for_display.to_a).to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_terminated"
      enrollment.external_enrollment = true
      enrollment.save!
      expect(family.enrollments_for_display.to_a).to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_selected"
      enrollment.external_enrollment = true
      enrollment.save!
      expect(family.enrollments_for_display.to_a).to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_canceled"
      enrollment.external_enrollment = false
      enrollment.save!
      expect(family.enrollments_for_display.to_a).to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_canceled"
      enrollment.external_enrollment = true
      enrollment.save!
      expect(family.enrollments_for_display.to_a).to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_selected"
      enrollment.external_enrollment = false
      enrollment.save!
      expect(family.enrollments_for_display.to_a).not_to eq([])
    end

    it "should not be visible to the family" do
      enrollment.aasm_state = "coverage_terminated"
      enrollment.external_enrollment = false
      enrollment.save!
      expect(family.enrollments_for_display.to_a).not_to eq([])
    end
  end

  context "for cobra", :dbclean => :after_each do
    let(:enrollment) {HbxEnrollment.new(kind: 'employer_sponsored')}
    let(:cobra_enrollment) {HbxEnrollment.new(kind: 'employer_sponsored_cobra')}

    context "is_cobra_status?" do
      it "should return false" do
        expect(enrollment.is_cobra_status?).to be_falsey
      end

      it "should return true" do
        enrollment.kind = 'employer_sponsored_cobra'
        expect(enrollment.is_cobra_status?).to be_truthy
      end
    end

    context "cobra_future_active?" do
      it "should return false when not cobra" do
        expect(enrollment.cobra_future_active?).to be_falsey
      end

      context "when cobra" do
        it "should return false" do
          allow(cobra_enrollment).to receive(:future_active?).and_return false
          expect(cobra_enrollment.cobra_future_active?).to be_falsey
        end

        it "should return true" do
          allow(cobra_enrollment).to receive(:future_active?).and_return true
          expect(cobra_enrollment.cobra_future_active?).to be_truthy
        end
      end
    end

    context "future_enrollment_termination_date" do
      let(:employee_role) {FactoryBot.create(:employee_role)}
      let(:census_employee) {FactoryBot.create(:census_employee)}
      let(:coverage_termination_date) {TimeKeeper.date_of_record + 1.months}

      it "should return blank if not coverage_termination_pending" do
        expect(enrollment.future_enrollment_termination_date).to eq ""
      end

      it "should return coverage_termination_date by census_employee" do
        census_employee.coverage_terminated_on = coverage_termination_date
        employee_role.census_employee = census_employee
        enrollment.employee_role = employee_role
        enrollment.aasm_state = "coverage_termination_pending"
        expect(enrollment.future_enrollment_termination_date).to eq coverage_termination_date
      end
    end

    it "can_select_coverage?" do
      enrollment.kind = 'employer_sponsored_cobra'
      expect(enrollment.can_select_coverage?).to be_truthy
    end

    context "benefit_package_name" do
      let(:benefit_group) {FactoryBot.create(:benefit_group)}
      let(:benefit_package) {BenefitPackage.new(title: 'benefit package title')}
      it "for shop" do
        enrollment.kind = 'employer_sponsored'
        enrollment.benefit_group = benefit_group
        expect(enrollment.benefit_package_name).to eq benefit_group.title
      end
    end
  end

  describe HbxEnrollment, 'Updating Existing Coverage', type: :model, dbclean: :after_each do

    include_context "setup benefit market with market catalogs and product packages"

    let(:effective_on) { current_effective_date }
    let(:hired_on) { TimeKeeper.date_of_record - 3.months }

    let(:person) {FactoryBot.create(:person, :with_ssn)}
    let(:shop_family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}

    let(:aasm_state) { :active }
    let(:census_employee) do
      create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, employee_role_id: employee_role.id)
    end
    let!(:employee_role) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: hired_on, person: person) }
    let(:enrollment_kind) { "open_enrollment" }
    let(:special_enrollment_period_id) { nil }

    let!(:enrollment) do
      shop_family.latest_household.hbx_enrollments.create!(
        coverage_kind: "health",
        effective_on: effective_on,
        enrollment_kind: enrollment_kind,
        kind: "employer_sponsored",
        submitted_at: effective_on - 20.days,
        benefit_sponsorship_id: benefit_sponsorship.id,
        sponsored_benefit_package_id: current_benefit_package.id,
        sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
        employee_role_id: employee_role.id,
        benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
        special_enrollment_period_id: special_enrollment_period_id,
        product_id: current_benefit_package.sponsored_benefits[0].reference_product.id,
        aasm_state: "coverage_selected"
      )
    end

    before do
      employee_role.update(census_employee_id: census_employee.id)
    end

    context 'When family has active coverage and makes changes for their coverage', dbclean: :after_each do

      include_context "setup initial benefit application"

      let(:special_enrollment_period) do
        FactoryBot.create(:special_enrollment_period, family: shop_family)
      end
      let(:new_enrollment_eff_on)  { TimeKeeper.date_of_record.next_month.beginning_of_month }

      let(:new_enrollment) do
        shop_family.latest_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: new_enrollment_eff_on,
          enrollment_kind: enrollment_kind,
          kind: "employer_sponsored",
          submitted_at: TimeKeeper.date_of_record,
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          special_enrollment_period_id: special_enrollment_period.id,
          predecessor_enrollment_id: enrollment.id,
          aasm_state: 'shopping'
        )
      end
      let(:terminated_date)  { new_enrollment_eff_on - 1.day }

      it 'should terminate existing coverage' do
        expect(enrollment.coverage_selected?).to be_truthy
        expect(enrollment.terminated_on).to be_nil
        new_enrollment.select_coverage!
        enrollment.reload
        if terminated_date <= TimeKeeper.date_of_record
          expect(enrollment.coverage_terminated?).to be_truthy
        else
          expect(enrollment.coverage_termination_pending?).to be_truthy
        end
        expect(enrollment.terminated_on).to eq(terminated_date)
      end
    end

    context 'when renewing coverage is waived' do
      include_context "setup initial benefit application"

      let(:enrollment_effective_on) {TimeKeeper.date_of_record - 15.days}
      let(:shopping_waived_enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: shop_family.latest_household,
          coverage_kind: 'health',
          effective_on: enrollment_effective_on,
          enrollment_kind: enrollment_kind,
          kind: 'employer_sponsored',
          submitted_at: TimeKeeper.date_of_record,
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          predecessor_enrollment_id: enrollment.id,
          product_id: enrollment.product_id,
          aasm_state: 'shopping'
        )
      end

      it 'should update benefit_group_assignment state to coverage_waived' do
        expect(shopping_waived_enrollment.aasm_state).to eq 'shopping'
        expect(shopping_waived_enrollment.benefit_group_assignment.aasm_state).to eq 'initialized'
        shopping_waived_enrollment.renew_waived!
        expect(shopping_waived_enrollment.aasm_state).to eq 'renewing_waived'
        expect(shopping_waived_enrollment.benefit_group_assignment.aasm_state).to eq 'coverage_waived'
      end
    end

    context 'When family passively renewed', dbclean: :after_each do
      include_context "setup renewal application"

      let(:predecessor_application_catalog) { true }
      let(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month - 1.year }
      let(:renewal_state) { :enrollment_open }
      let(:open_enrollment_period)  { TimeKeeper.date_of_record..(effective_period.min - 10.days) }
      let(:current_benefit_package) { renewal_application.predecessor.benefit_packages[0] }

      let(:generate_passive_renewal) do
        census_employee.update!(created_at: 2.months.ago)
        census_employee.assign_to_benefit_package(benefit_package, renewal_effective_date)
        benefit_package.renew_member_benefit(census_employee)
      end

      let(:enrollment_effective_on) { renewal_effective_date }
      let(:special_enrollment_period_id) { nil }
      let(:passive_renewal) { shop_family.reload.enrollments.where(:aasm_state => 'auto_renewing').first }

      context 'When Actively Renewed', dbclean: :after_each do

        let(:new_enrollment_product_id) { passive_renewal.product_id }

        let(:new_enrollment) do
          create(
            :hbx_enrollment,
            household: shop_family.latest_household,
            coverage_kind: "health",
            effective_on: enrollment_effective_on,
            enrollment_kind: enrollment_kind,
            kind: "employer_sponsored",
            submitted_at: TimeKeeper.date_of_record,
            benefit_sponsorship_id: benefit_sponsorship.id,
            sponsored_benefit_package_id: benefit_package.id,
            sponsored_benefit_id: benefit_package.sponsored_benefits[0].id,
            employee_role_id: employee_role.id,
            benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id,
            predecessor_enrollment_id: passive_renewal.id,
            product_id: new_enrollment_product_id,
            special_enrollment_period_id: special_enrollment_period_id,
            aasm_state: 'shopping'
          )
        end

        before do
          allow(benefit_package).to receive(:is_renewal_benefit_available?).and_return(true)
          allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
          generate_passive_renewal
        end

        context 'with same effective date as passive renewal' do

          it 'should cancel their passive renewal' do
            expect(passive_renewal).not_to be_nil

            new_enrollment.select_coverage!
            passive_renewal.reload
            new_enrollment.reload

            expect(passive_renewal.coverage_canceled?).to be_truthy
            expect(new_enrollment.coverage_selected?).to be_truthy
          end
        end

        context 'with effective date later to the passive renewal' do

          let(:enrollment_effective_on) { renewal_effective_date.next_month }

          it 'should terminate the passive renewal' do
            expect(passive_renewal).not_to be_nil

            new_enrollment.select_coverage!
            passive_renewal.reload
            new_enrollment.reload

            expect(new_enrollment.coverage_selected?).to be_truthy
            expect(passive_renewal.coverage_termination_pending?).to be_truthy
            expect(passive_renewal.terminated_on).to eq(new_enrollment.effective_on - 1.day)
          end
        end
      end

      context '.update_renewal_coverage', dbclean: :after_each do

        let(:issuer_profile) { FactoryBot.create(:benefit_sponsors_organizations_issuer_profile) }
        before do
          allow(benefit_package).to receive(:is_renewal_benefit_available?).and_return(true)
          allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
          generate_passive_renewal
        end

        context 'when EE enters SEP and picks new plan' do
          let(:enrollment_effective_on) { renewal_effective_date - 3.months }

          let(:new_enrollment) do
            shop_family.latest_household.hbx_enrollments.create(
              coverage_kind: "health",
              effective_on: enrollment_effective_on,
              enrollment_kind: enrollment_kind,
              kind: "employer_sponsored",
              submitted_at: TimeKeeper.date_of_record,
              benefit_sponsorship_id: benefit_sponsorship.id,
              sponsored_benefit_package_id: current_benefit_package.id,
              sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
              employee_role_id: employee_role.id,
              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
              predecessor_enrollment_id: enrollment.id,
              product_id: new_enrollment_product.id,
              special_enrollment_period_id: special_enrollment_period_id,
              aasm_state: 'shopping'
            )
          end

          let(:new_enrollment_product) do
            product_package = current_benefit_package.sponsored_benefits[0].product_package
            product_package.products.detect{|product| product != enrollment.product }
          end

          let(:special_enrollment_period_id) { FactoryBot.create(:special_enrollment_period, family: shop_family).id }

          it 'should cancel passive renewal and create new passive' do
            expect(passive_renewal).not_to be_nil
            new_enrollment.select_coverage!
            passive_renewal.reload
            new_enrollment.reload
            enrollment.reload
            expect(enrollment.coverage_terminated?).to be_truthy
            expect(passive_renewal.coverage_canceled?).to be_truthy
            expect(new_enrollment.coverage_selected?).to be_truthy
            new_passive = shop_family.reload.active_household.hbx_enrollments.where(:aasm_state => :auto_renewing, :effective_on => renewal_effective_date).first
            expect(new_passive.product).to eq new_enrollment_product.renewal_product
          end

          context 'when employee actively renewed coverage' do

            it 'should not cancel active renewal and should not generate passive' do
              passive_renewal.update(aasm_state: 'coverage_selected')
              new_enrollment.select_coverage!
              passive_renewal.reload
              enrollment.reload
              expect(enrollment.coverage_terminated?).to be_truthy
              expect(new_enrollment.coverage_selected?).to be_truthy
              expect(passive_renewal.coverage_canceled?).to be_falsey
              new_passive = shop_family.reload.enrollments.by_coverage_kind('health').where(:aasm_state => 'auto_renewing').first
              expect(new_passive.blank?).to be_truthy
            end
          end
        end

        context 'when EE terminates current coverage' do

          let(:new_enrollment) do
            FactoryBot.create(:hbx_enrollment,
                              household: shop_family.latest_household,
                              coverage_kind: "health",
                              effective_on: enrollment_effective_on,
                              enrollment_kind: enrollment_kind,
                              kind: "employer_sponsored",
                              submitted_at: TimeKeeper.date_of_record,
                              benefit_sponsorship_id: benefit_sponsorship.id,
                              sponsored_benefit_package_id: current_benefit_package.id,
                              sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                              employee_role_id: employee_role.id,
                              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                              predecessor_enrollment_id: enrollment.id,
                              product_id: enrollment.product_id,
                              aasm_state: 'shopping')
          end

          it 'should cancel passive renewal and generate a waiver' do
            expect(passive_renewal).not_to be_nil
            enrollment.terminate_enrollment(TimeKeeper.date_of_record.last_month.end_of_month, 'Because')
            passive_renewal.reload
            enrollment.reload
            expect(enrollment.coverage_terminated?).to be_truthy
            # TODO: Can't ifgure why this isn't working
            # Why would a passive rnewal be equal to coverage cancelled?
            # expect(passive_renewal.coverage_canceled?).to be_truthy
            waiver = shop_family.reload.enrollments.where(:aasm_state => 'inactive').first
            expect(waiver.present?).to be_truthy
          end

          it 'should cancel passive renewal and should not generate a duplicate waiver' do
            expect(passive_renewal).not_to be_nil
            new_enrollment.waive_coverage!
            new_enrollment.schedule_coverage_termination!
            passive_renewal.reload
            enrollment.reload
            new_enrollment.reload
            expect(new_enrollment.inactive?).to be_truthy
            expect(passive_renewal.coverage_canceled?).to be_truthy
            passive_waiver = shop_family.reload.enrollments.where(:aasm_state => 'renewing_waived').first
            expect(passive_waiver.present?).to be_falsey
          end
        end
      end

      context '.update_expected_selection' do
        context "Health" do
          let(:new_enrollment) do
            FactoryBot.create(:hbx_enrollment,
                              household: shop_family.latest_household,
                              coverage_kind: 'health',
                              effective_on: enrollment_effective_on,
                              enrollment_kind: enrollment_kind,
                              kind: 'employer_sponsored',
                              submitted_at: TimeKeeper.date_of_record,
                              benefit_sponsorship_id: benefit_sponsorship.id,
                              sponsored_benefit_package_id: current_benefit_package.id,
                              sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                              employee_role_id: employee_role.id,
                              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                              product_id: enrollment.product_id,
                              aasm_state: 'shopping')
          end

          let(:new_enrollment2) do
            FactoryBot.create(:hbx_enrollment,
                              household: shop_family.latest_household,
                              coverage_kind: 'health',
                              effective_on: enrollment_effective_on,
                              enrollment_kind: enrollment_kind,
                              kind: 'employer_sponsored',
                              submitted_at: TimeKeeper.date_of_record,
                              benefit_sponsorship_id: benefit_sponsorship.id,
                              sponsored_benefit_package_id: current_benefit_package.id,
                              sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                              employee_role_id: employee_role.id,
                              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                              product_id: enrollment.product_id,
                              aasm_state: 'shopping')
          end

          context 'when census_employee is not cobra' do
            before do
              new_enrollment.waive_coverage!
            end

            context 'employee waives the coverage' do
              it 'should update expected_selection on census employee to waive' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'waive'
              end
            end

            context 'employee waives and enroll in coverage' do
              it 'should update expected_selection on census employee to enroll' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'waive'
                new_enrollment2.select_coverage!
                new_enrollment.census_employee.reload
                expect(new_enrollment.census_employee.expected_selection).to eq 'enroll'
              end
            end
          end

          context 'when there is no census_employee record' do
            let(:new_enrollment) do
              FactoryBot.create(:hbx_enrollment,
                                household: shop_family.latest_household,
                                coverage_kind: 'health',
                                effective_on: enrollment_effective_on,
                                enrollment_kind: enrollment_kind,
                                kind: 'employer_sponsored',
                                submitted_at: TimeKeeper.date_of_record,
                                benefit_sponsorship_id: benefit_sponsorship.id,
                                sponsored_benefit_package_id: current_benefit_package.id,
                                sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                                product_id: enrollment.product_id,
                                aasm_state: 'shopping')
            end

            it 'should not raise error when no census employee' do
              new_enrollment.waive_coverage!
              expect(new_enrollment.census_employee.present?).to be_falsey
            end
          end

          context 'when census_employee is cobra eligible' do
            before do
              new_enrollment.census_employee.update_attributes!(aasm_state: 'cobra_eligible', cobra_begin_date: (Date.today - 1.month).beginning_of_month)
              new_enrollment.waive_coverage!
            end

            context 'employee waives the coverage' do
              it 'should not update expected_selection on census employee to waive' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'enroll'
              end
            end

            context 'employee waives and enroll in coverage' do
              it 'should not update expected_selection on census employee' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'enroll'
                new_enrollment2.select_coverage!
                new_enrollment.census_employee.reload
                expect(new_enrollment.census_employee.expected_selection).to eq 'enroll'
              end
            end
          end
        end

        context "Dental" do
          let(:dental_sponsored_benefit) { true }
          let(:product_kinds)  { [:health, :dental] }

          let(:new_enrollment) do
            FactoryBot.create(:hbx_enrollment,
                              household: shop_family.latest_household,
                              coverage_kind: 'dental',
                              effective_on: enrollment_effective_on,
                              enrollment_kind: enrollment_kind,
                              kind: 'employer_sponsored',
                              submitted_at: TimeKeeper.date_of_record,
                              benefit_sponsorship_id: benefit_sponsorship.id,
                              sponsored_benefit_package_id: current_benefit_package.id,
                              sponsored_benefit_id: current_benefit_package.sponsored_benefits[1].id,
                              employee_role_id: employee_role.id,
                              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                              product_id: enrollment.product_id,
                              aasm_state: 'shopping')


          end

          let(:new_enrollment2) do
            FactoryBot.create(:hbx_enrollment,
                              household: shop_family.latest_household,
                              coverage_kind: 'dental',
                              effective_on: enrollment_effective_on,
                              enrollment_kind: enrollment_kind,
                              kind: 'employer_sponsored',
                              submitted_at: TimeKeeper.date_of_record,
                              benefit_sponsorship_id: benefit_sponsorship.id,
                              sponsored_benefit_package_id: current_benefit_package.id,
                              sponsored_benefit_id: current_benefit_package.sponsored_benefits[1].id,
                              employee_role_id: employee_role.id,
                              benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                              product_id: enrollment.product_id,
                              aasm_state: 'shopping')
          end

          context 'when census_employee is not cobra' do
            before do
              new_enrollment.waive_coverage!
            end

            context 'employee waives the coverage' do
              it 'should update expected_selection on census employee to waive' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'waive'
              end
            end

            context 'employee waives and enroll in coverage' do
              it 'should update expected_selection on census employee to enroll' do
                expect(new_enrollment.census_employee.expected_selection).to eq 'waive'
                new_enrollment2.select_coverage!
                new_enrollment.census_employee.reload
                expect(new_enrollment.census_employee.expected_selection).to eq 'enroll'
              end
            end
          end
        end
      end

      context '.renewal_enrollments', dbclean: :around_each do
        let(:new_enrollment_product_id) { passive_renewal.product_id }
        let(:new_enrollment) do
          create(
            :hbx_enrollment,
            household: shop_family.latest_household,
            coverage_kind: "health",
            effective_on: enrollment_effective_on,
            enrollment_kind: enrollment_kind,
            kind: "employer_sponsored",
            submitted_at: TimeKeeper.date_of_record,
            benefit_sponsorship_id: benefit_sponsorship.id,
            sponsored_benefit_package_id: benefit_package.id,
            sponsored_benefit_id: benefit_package.sponsored_benefits[0].id,
            employee_role_id: employee_role.id,
            benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id,
            predecessor_enrollment_id: passive_renewal.id,
            product_id: new_enrollment_product_id,
            special_enrollment_period_id: special_enrollment_period_id,
            aasm_state: 'shopping'
          )
        end

        before do
          allow(benefit_package).to receive(:is_renewal_benefit_available?).and_return(true)
          generate_passive_renewal
        end

        it 'should return enrollments by family' do
          enrollments = new_enrollment.renewal_enrollments(renewal_application)

          expect(enrollments).to include(passive_renewal)
        end
      end
    end

    context '.term_existing_shop_enrollments' do
      include_context "setup renewal application"

      let(:predecessor_application_catalog) { true }
      let(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month - 1.year }
      let(:renewal_state) { :enrollment_open }
      let(:open_enrollment_period)  { TimeKeeper.date_of_record..(effective_period.min - 10.days) }
      let(:current_benefit_package) { renewal_application.predecessor.benefit_packages[0] }
      let(:renewal_benefit_package) { renewal_application.benefit_packages[0] }

      let(:generate_passive_waiver) do
        enrollment.update_attributes(aasm_state: 'inactive')
        renewal_application.benefit_packages[0].update_attributes(title: current_benefit_package.title + "(#{renewal_application.start_on.year})")
        census_employee.update!(created_at: 2.months.ago)
        census_employee.assign_to_benefit_package(benefit_package, renewal_effective_date)
        benefit_package.renew_member_benefit(census_employee)
      end

      let(:generate_passive_renewal) do
        enrollment.update_attributes(aasm_state: 'coverage_enrolled')
        renewal_application.benefit_packages[0].update_attributes(title: current_benefit_package.title + "(#{renewal_application.start_on.year})")
        census_employee.update!(created_at: 2.months.ago)
        census_employee.assign_to_benefit_package(benefit_package, renewal_effective_date)
        benefit_package.renew_member_benefit(census_employee)
      end

      let(:enrollment_effective_on) { renewal_effective_date }
      let(:special_enrollment_period_id) { nil }
      let(:passive_renewal_waived)  { shop_family.reload.enrollments.renewing_waived.first }
      let(:auto_renewal_enrollment) { shop_family.reload.enrollments.auto_renewing.first }
      let(:new_waiver_under_renewal_app) do
        build(
          :hbx_enrollment,
          kind: 'employer_sponsored',
          coverage_kind: passive_renewal_waived.coverage_kind,
          household: shop_family.active_household,
          benefit_sponsorship_id: benefit_sponsorship.id,
          aasm_state: "shopping",
          predecessor_enrollment_id: passive_renewal_waived.id,
          sponsored_benefit_package_id: renewal_benefit_package.id,
          sponsored_benefit_id: renewal_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id
        )
      end

      let(:auto_renewing_under_renewal_app) do
        build(
          :hbx_enrollment,
          kind: 'employer_sponsored',
          coverage_kind: auto_renewal_enrollment.coverage_kind,
          household: shop_family.active_household,
          benefit_sponsorship_id: benefit_sponsorship.id,
          aasm_state: "shopping",
          predecessor_enrollment_id: auto_renewal_enrollment.id,
          sponsored_benefit_package_id: renewal_benefit_package.id,
          sponsored_benefit_id: renewal_benefit_package.sponsored_benefits[0].id,
          effective_on: renewal_benefit_package.start_on,
          employee_role_id: employee_role.id,
          benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id
        )
      end

      before do
        allow(benefit_package).to receive(:is_renewal_benefit_available?).and_return(true)
      end

      it 'should cancel future effective waivers upon creating a new waiver' do
        generate_passive_waiver
        new_waiver_under_renewal_app.waive_enrollment
        expect(passive_renewal_waived.reload.coverage_canceled?).to be_truthy
      end

      it 'should terminate previous active enrollment when waiving passive renewal in open enrollment' do
        generate_passive_renewal
        auto_renewal_enrollment.update_attributes(predecessor_enrollment_id: enrollment.id)
        auto_renewing_under_renewal_app.waive_enrollment
        expect(enrollment.reload.coverage_termination_pending?).to be_truthy
        expect(enrollment.terminated_on).to eq((enrollment.effective_on + 1.year) - 1.day)
      end

      it 'should terminate previous active enrollment when waiving renewal coverage selected enrollment in open enrollment' do
        generate_passive_renewal
        auto_renewing_under_renewal_app.waive_enrollment
        expect(enrollment.reload.coverage_termination_pending?).to be_truthy
        expect(enrollment.terminated_on).to eq((enrollment.effective_on + 1.year) - 1.day)
      end
    end

    context "market_name" do
      include_context "setup initial benefit application"

      it "for shop" do
        enrollment.kind = 'employer_sponsored'
        expect(enrollment.market_name).to eq 'Employer Sponsored'
      end

      it "for individual" do
        enrollment.kind = 'individual'
        expect(enrollment.market_name).to eq 'Individual'
      end
    end
  end

  describe HbxEnrollment, 'Voiding enrollments', type: :model, dbclean: :after_each do
    let!(:hbx_profile) {FactoryBot.create(:hbx_profile)}
    let(:family) {FactoryBot.build(:individual_market_family)}
    let(:hbx_enrollment) {FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, effective_on: TimeKeeper.date_of_record)}

    context "Enrollment is in active state" do
      it "enrollment is in coverage_selected state" do
        expect(hbx_enrollment.coverage_selected?).to be_truthy
      end

      context "and the enrollment is invalidated" do
        it "enrollment should transition to void state" do
          hbx_enrollment.invalidate_enrollment!
          expect(HbxEnrollment.find(hbx_enrollment.id).void?).to be_truthy
        end
      end
    end

    context "Enrollment is in terminated state" do
      before do
        hbx_enrollment.terminate_benefit(TimeKeeper.date_of_record - 2.months)
        hbx_enrollment.save!
      end

        # Although slower, it's essential to read the record from DB, as the in-memory version may differ
      it "enrollment is in terminated state" do
        expect(HbxEnrollment.find(hbx_enrollment.id).coverage_terminated?).to be_truthy
      end

      context "and the enrollment is invalidated" do
        before do
          hbx_enrollment.invalidate_enrollment
          hbx_enrollment.save!
        end

        it "enrollment should transition to void state" do
          expect(HbxEnrollment.find(hbx_enrollment.id).void?).to be_truthy
        end

        it "terminated_on value should be null" do
          expect(HbxEnrollment.find(hbx_enrollment.id).terminated_on).to be_nil
        end

        it "terminate_reason value should be null" do
          expect(HbxEnrollment.find(hbx_enrollment.id).terminate_reason).to be_nil
        end
      end
    end
  end

  describe HbxEnrollment, 'Renewal Purchase', type: :model, dbclean: :after_each do
    let(:family) {FactoryBot.build(:individual_market_family)}
    let(:hbx_enrollment) {FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, kind: 'individual')}

    context "open enrollment" do
      before do
        hbx_enrollment.update(enrollment_kind: 'open_enrollment')
      end

      it "should return true when auto_renewing" do
        FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, aasm_state: 'auto_renewing')
        expect(hbx_enrollment.is_active_renewal_purchase?).to be_truthy
      end

      it "should return true when renewing_coverage_selected" do
        FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, aasm_state: 'renewing_coverage_selected')
        expect(hbx_enrollment.is_active_renewal_purchase?).to be_truthy
      end

      it "should return false when coverage_selected" do
        FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, aasm_state: 'coverage_selected')
        expect(hbx_enrollment.is_active_renewal_purchase?).to be_falsey
      end
    end

    it "should return false when it is not open_enrollment" do
      hbx_enrollment.update(enrollment_kind: 'special_enrollment')
      expect(hbx_enrollment.is_active_renewal_purchase?).to be_falsey
    end

    it "should return false when it is individual" do
      hbx_enrollment.update(kind: 'employer_sponsored')
      expect(hbx_enrollment.is_active_renewal_purchase?).to be_falsey
    end
  end

  describe HbxEnrollment, 'state machine', dbclean: :after_each do
    let(:family) {FactoryBot.build(:individual_market_family)}
    let(:aasm_state) { 'coverage_selected' }
    subject {FactoryBot.build(:hbx_enrollment, :individual_unassisted, household: family.active_household, aasm_state: aasm_state)}

    events = [:move_to_enrolled, :move_to_contingent, :move_to_pending]

    shared_examples_for "state machine transitions" do |current_state, new_state, event|
      it "transition #{current_state} to #{new_state} on #{event} event" do
        expect(subject).to transition_from(current_state).to(new_state).on_event(event)
      end
    end

    context "move_to_enrolled event" do
      it_behaves_like "state machine transitions", :unverified, :coverage_selected, :move_to_enrolled
      it_behaves_like "state machine transitions", :enrolled_contingent, :coverage_selected, :move_to_enrolled
    end

    context "move_to_contingent event" do
      it_behaves_like "state machine transitions", :shopping, :enrolled_contingent, :move_to_contingent!
      it_behaves_like "state machine transitions", :coverage_selected, :enrolled_contingent, :move_to_contingent!
      it_behaves_like "state machine transitions", :unverified, :enrolled_contingent, :move_to_contingent!
      it_behaves_like "state machine transitions", :coverage_enrolled, :enrolled_contingent, :move_to_contingent!
      it_behaves_like "state machine transitions", :auto_renewing, :enrolled_contingent, :move_to_contingent!
    end

    context "move_to_pending event" do
      it_behaves_like "state machine transitions", :shopping, :unverified, :move_to_pending!
      it_behaves_like "state machine transitions", :coverage_selected, :unverified, :move_to_pending!
      it_behaves_like "state machine transitions", :enrolled_contingent, :unverified, :move_to_pending!
      it_behaves_like "state machine transitions", :coverage_enrolled, :unverified, :move_to_pending!
      it_behaves_like "state machine transitions", :auto_renewing, :unverified, :move_to_pending!
    end

    context 'update_employee_roster' do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup renewal application"

      let(:family_0) { create(:family, :with_primary_family_member_and_dependent) }
      let(:person_0) { family_0.primary_person }
      let(:dependents_0) { family_0.family_members.where(is_primary_applicant: false) }
      let(:dependent_person) { dependents_0.first.person }
      let!(:census_dependent_0){ build(:census_dependent, first_name: dependent_person.first_name, last_name: dependent_person.last_name, dob: dependent_person.dob)}
      let!(:census_employee_0) do
        create(
          :benefit_sponsors_census_employee,
          :benefit_sponsorship => benefit_sponsorship,
          :employer_profile => abc_profile,
          :census_dependents => [census_dependent_0]
        )
      end
      let(:aasm_state) { 'coverage_enrolled' }
      let(:hbx_enrollment_0) do
        create(
          :hbx_enrollment,
          :with_enrollment_members,
          :with_product,
          household: family_0.active_household,
          aasm_state: aasm_state,
          effective_on: predecessor_application.start_on,
          rating_area_id: predecessor_application.recorded_rating_area_id,
          sponsored_benefit_id: predecessor_application.benefit_packages.first.health_sponsored_benefit.id,
          sponsored_benefit_package_id: predecessor_application.benefit_packages.first.id,
          benefit_sponsorship_id: predecessor_application.benefit_sponsorship.id,
          employee_role_id: employee_role_0.id
        )
      end
      let(:employee_role_0) { create(:benefit_sponsors_employee_role, person: person_0, census_employee_id: census_employee_0.id, benefit_sponsors_employer_profile_id: abc_profile.id)}

      context 'event transitions to coverage_selected' do
        let(:aasm_state) { 'shopping' }

        context 'and employee roster updates are turned on' do
          before { EnrollRegistry[:employee_roster_updates].feature.stub(:is_enabled).and_return(true) }

          it 'should call operation' do
            expect(Operations::CensusMembers::Update).to receive_message_chain('new.call').with(hbx_enrollment: hbx_enrollment_0, action: 'update_census_family')
            hbx_enrollment_0.select_coverage!
          end

          context 'and employer turned on roster updates' do
            before { abc_profile.update_attributes(enable_roster_updates: true) }

            it 'should call operation' do
              expect(Operations::CensusMembers::Update).to receive_message_chain('new.call').with(hbx_enrollment: hbx_enrollment_0, action: 'update_census_family')
              hbx_enrollment_0.select_coverage!
            end
          end

          context 'and employer turned off roster updates' do
            before { abc_profile.update_attributes(enable_roster_updates: false) }

            it 'should not call operation' do
              expect(Operations::CensusMembers::Update).not_to receive(:new)
              hbx_enrollment_0.select_coverage!
            end
          end
        end

        context 'and employee roster updates are turned off' do
          before { EnrollRegistry[:employee_roster_updates].feature.stub(:is_enabled).and_return(false) }

          it 'should not call operation' do
            expect(Operations::CensusMembers::Update).not_to receive(:new)
            hbx_enrollment_0.select_coverage!
          end
        end
      end

      context 'event transitions to coverage_terminated' do
        let(:aasm_state) { 'coverage_selected' }

        context 'and employee roster updates are turned on' do
          before { EnrollRegistry[:employee_roster_updates].feature.stub(:is_enabled).and_return(true) }

          it 'should not call operation' do
            expect(Operations::CensusMembers::Update).not_to receive(:new)
            hbx_enrollment_0.terminate_coverage!
          end
        end
      end
    end
  end

  describe HbxEnrollment, 'validate_for_cobra_eligiblity', dbclean: :after_each do

    context 'When employee is designated as cobra' do

      let(:effective_on) {TimeKeeper.date_of_record.beginning_of_month}
      let(:cobra_begin_date) {TimeKeeper.date_of_record.next_month.beginning_of_month}
      let(:hbx_enrollment) {HbxEnrollment.new(kind: 'employer_sponsored', effective_on: effective_on)}
      let(:employee_role) {double(is_cobra_status?: true, census_employee: census_employee)}
      let(:census_employee) {double(cobra_begin_date: cobra_begin_date, have_valid_date_for_cobra?: true, coverage_terminated_on: cobra_begin_date - 1.day)}

      before do
        allow(hbx_enrollment).to receive(:employee_role).and_return(employee_role)
      end

      context 'When Enrollment Effectve date is prior to cobra begin date' do
        it 'should reset enrollment effective date to cobra begin date' do
          hbx_enrollment.validate_for_cobra_eligiblity(employee_role)
          expect(hbx_enrollment.kind).to eq 'employer_sponsored_cobra'
          expect(hbx_enrollment.effective_on).to eq cobra_begin_date
        end
      end

      context 'When Enrollment Effectve date is after cobra begin date' do
        let(:cobra_begin_date) {TimeKeeper.date_of_record.prev_month.beginning_of_month}

        it 'should not update enrollment effective date' do
          hbx_enrollment.validate_for_cobra_eligiblity(employee_role)
          expect(hbx_enrollment.kind).to eq 'employer_sponsored_cobra'
          expect(hbx_enrollment.effective_on).to eq effective_on
        end
      end

      context 'When employee not elgibile for cobra' do
        let(:census_employee) {double(cobra_begin_date: cobra_begin_date, have_valid_date_for_cobra?: false, coverage_terminated_on: cobra_begin_date - 1.day)}

        it 'should raise error' do
          expect {hbx_enrollment.validate_for_cobra_eligiblity(employee_role)}.not_to raise_error("You may not enroll for cobra after #{Settings.aca.shop_market.cobra_enrollment_period.months} months later of coverage terminated.")
        end
      end
    end
  end

  describe HbxEnrollment, '.build_plan_premium', type: :model, dbclean: :after_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let!(:employer_profile) {benefit_sponsorship.profile}
    let(:benefit_group) {employer_profile.published_plan_year.benefit_groups.first}

    let!(:census_employees) do
      FactoryBot.create :census_employee, :owner, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship
      employee = FactoryBot.create :census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship
      employee.add_benefit_group_assignment benefit_group, benefit_group.start_on
    end

    let!(:plan) do
      FactoryBot.create(:plan, :with_premium_tables, market: 'shop', metal_level: 'gold', active_year: benefit_group.start_on.year, hios_id: "11111111122302-01", csr_variant_id: "01")
    end

    let(:ce) {employer_profile.census_employees.non_business_owner.first}

    let!(:family) do
      person = FactoryBot.create(:person, last_name: ce.last_name, first_name: ce.first_name)
      employee_role = FactoryBot.create(:employee_role, person: person, census_employee: ce, benefit_sponsors_employer_profile_id: employer_profile.id)
      ce.update_attributes({employee_role: employee_role})
      Family.find_or_build_from_employee_role(employee_role)
    end

    let(:person) {family.primary_applicant.person}

    context 'Employer Sponsored Coverage' do
      let!(:enrollment) do
        family.active_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: benefit_group.start_on,
          enrollment_kind: "open_enrollment",
          kind: "employer_sponsored",
          sponsored_benefit_package_id: benefit_group.id,
          employee_role_id: person.active_employee_roles.first.id,
          benefit_group_assignment_id: ce.active_benefit_group_assignment.id,
          plan_id: plan.id
        )
      end

      context 'for congression employer' do
        before do
          allow(enrollment).to receive_message_chain("benefit_group.is_congress") {true}
        end

        it "should build premiums" do
          plan = enrollment.build_plan_premium(qhp_plan: enrollment.plan)
          expect(plan).to be_kind_of(PlanCostDecoratorCongress)
        end
      end

      context 'for non congression employer' do
        before do
          allow(enrollment).to receive_message_chain("benefit_group.is_congress") {false}
          allow(enrollment).to receive(:composite_rated?).and_return(false)
          allow(enrollment).to receive_message_chain("benefit_group.reference_plan") { plan }
        end

        it "should build premiums" do
          plan = enrollment.build_plan_premium(qhp_plan: enrollment.plan)
          expect(plan).to be_kind_of(PlanCostDecorator)
        end
      end
    end

    context 'Individual Coverage' do
      let!(:enrollment) do
        family.active_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: TimeKeeper.date_of_record.beginning_of_month,
          enrollment_kind: "open_enrollment",
          kind: "individual",
          plan_id: plan.id
        )
      end

      it "should build premiums" do
        plan = enrollment.build_plan_premium(qhp_plan: plan)
        expect(plan).to be_kind_of(UnassistedPlanCostDecorator)
      end
    end
  end

  describe HbxEnrollment, dbclean: :after_each do
    include_context "BradyWorkAfterAll"

    before :all do
      create_brady_census_families
    end

    context "Cancel / Terminate Previous Enrollments for Shop" do
      let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
      let(:existing_shop_enrollment) {FactoryBot.create(:hbx_enrollment, :shop, household: family.active_household, effective_on: TimeKeeper.date_of_record)}
      let(:new_enrollment) {FactoryBot.create(:hbx_enrollment, :shop, household: family.active_household, predecessor_enrollment_id: existing_shop_enrollment.id, effective_on: TimeKeeper.date_of_record)}

      it "should cancel the previous enrollment if the effective_on date of the previous and the current are the same." do
        new_enrollment.update_existing_shop_coverage
        existing_shop_enrollment.reload
        expect(existing_shop_enrollment.aasm_state).to eq "coverage_canceled"
      end
    end

    context "Cancel / Terminate Previous Enrollments for IVL" do
      attr_reader :enrollment, :household, :coverage_household

      let(:consumer_role) {FactoryBot.create(:consumer_role)}
      let(:hbx_profile) {FactoryBot.create(:hbx_profile)}
      let(:benefit_package) {hbx_profile.benefit_sponsorship.benefit_coverage_periods.first.benefit_packages.first}
      let(:benefit_coverage_period) {hbx_profile.benefit_sponsorship.benefit_coverage_periods.first}
      let(:family) {FactoryBot.build(:family)}

      before :each do
        @household = mikes_family.households.first
        @coverage_household = household.coverage_households.first
        allow(benefit_coverage_period).to receive(:earliest_effective_date).and_return TimeKeeper.date_of_record
        allow(coverage_household).to receive(:household).and_return household
        allow(household).to receive(:family).and_return family
        allow(family).to receive(:is_under_ivl_open_enrollment?).and_return true
        @enrollment1 = household.create_hbx_enrollment_from(consumer_role: consumer_role, coverage_household: coverage_household, benefit_package: benefit_package)
        @enrollment1.update_current(aasm_state: "coverage_selected", enrollment_signature: "somerandomthing!", effective_on: TimeKeeper.date_of_record.beginning_of_month)
        @enrollment2 = household.create_hbx_enrollment_from(consumer_role: consumer_role, coverage_household: coverage_household, benefit_package: benefit_package)
        @enrollment2.update_current(enrollment_signature: "somerandomthing!", effective_on: TimeKeeper.date_of_record.beginning_of_month)
      end

      it "should cancel the previous enrollment if the effective_on date of the previous and the current are the same." do
        @enrollment2.cancel_previous(TimeKeeper.date_of_record.year)
        expect(@enrollment1.aasm_state).to eq "coverage_canceled"
      end
    end
  end
end

describe HbxEnrollment, type: :model, :dbclean => :after_each do
  let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }

  include_context "setup benefit market with market catalogs and product packages" do
    let(:product_kinds)  { [:health, :dental] }
  end

  include_context "setup initial benefit application" do
    let(:dental_sponsored_benefit) { true }
  end

  describe ".renew_benefit", :dbclean => :after_each do
    describe "given an renewing employer just entered open enrollment", dbclean: :after_each do
      describe "with employees who have made the following plan selections previous year:
        - employee A has purchased:
          - One health enrollment (Enrollment 1)
          - One dental enrollment (Enrollment 2)
        - employee B has purchased:
          - One health enrollment (Enrollment 3)
          - One dental waiver (Enrollment 4)
        - employee C has purchased:
          - One health waiver (Enrollment 5)
          - One dental enrollment (Enrollment 6)
        - employee D has purchased:
          - One health waiver (Enrollment 7)
          - One dental waiver (Enrollment 8)
        - employee E has none
      ", dbclean: :after_each do


        let(:census_employees) do
          create_list(:census_employee, 5, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package)
        end

        let(:employee_A) do
          ce = census_employees[0]
          create_person(ce, abc_profile)
        end

        let!(:enrollment_1) do
          create_enrollment(family: employee_A.person.primary_family, benefit_group_assignment: employee_A.census_employee.active_benefit_group_assignment, employee_role: employee_A,
                            submitted_at: current_effective_date - 10.days)
        end

        let!(:enrollment_2) do
          create_enrollment(family: employee_A.person.primary_family, benefit_group_assignment: employee_A.census_employee.active_benefit_group_assignment, employee_role: employee_A,
                            submitted_at: current_effective_date - 10.days, coverage_kind: 'dental')
        end

        let(:employee_B) do
          ce = census_employees[1]
          create_person(ce, abc_profile)
        end

        let!(:enrollment_3) do
          create_enrollment(family: employee_B.person.primary_family, benefit_group_assignment: employee_B.census_employee.active_benefit_group_assignment, employee_role: employee_B,
                            submitted_at: current_effective_date - 10.days)
        end

        let!(:enrollment_4) do
          create_enrollment(family: employee_B.person.primary_family, benefit_group_assignment: employee_B.census_employee.active_benefit_group_assignment, employee_role: employee_B,
                            submitted_at: current_effective_date - 10.days, coverage_kind: 'dental', status: 'inactive')
        end

        let(:employee_C) do
          ce = census_employees[2]
          create_person(ce, abc_profile)
        end

        let!(:enrollment_5) do
          create_enrollment(family: employee_C.person.primary_family, benefit_group_assignment: employee_C.census_employee.active_benefit_group_assignment, employee_role: employee_C,
                            submitted_at: current_effective_date - 10.days, status: 'inactive')
        end

        let!(:enrollment_6) do
          create_enrollment(family: employee_C.person.primary_family, benefit_group_assignment: employee_C.census_employee.active_benefit_group_assignment, employee_role: employee_C,
                            submitted_at: current_effective_date - 10.days, coverage_kind: 'dental')
        end

        let(:employee_D) do
          ce = census_employees[3]
          create_person(ce, abc_profile)
        end

        let!(:enrollment_7) do
          create_enrollment(family: employee_D.person.primary_family, benefit_group_assignment: employee_D.census_employee.active_benefit_group_assignment, employee_role: employee_D,
                            submitted_at: current_effective_date - 10.days, status: 'inactive')
        end

        let!(:enrollment_8) do
          create_enrollment(family: employee_D.person.primary_family, benefit_group_assignment: employee_D.census_employee.active_benefit_group_assignment, employee_role: employee_D,
                            submitted_at: current_effective_date - 10.days, coverage_kind: 'dental', status: 'inactive')
        end

        let!(:employee_E) do
          ce = census_employees[3]
          create_person(ce, abc_profile)
        end

        let(:renewal_application) do
          renewal_effective_date = current_effective_date.next_year
          r_application = initial_application.renew
          r_application.save
          r_application
        end

        let(:renewal_benefit_package) do
          renewal_application.benefit_packages[0]
        end

        before do
          allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate).and_return(100.0)
          allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
          renewal_benefit_package.sponsored_benefits.each do |sponsored_benefit|
            allow(sponsored_benefit).to receive(:products).and_return(sponsored_benefit.product_package.products)
          end
          renewal_application
        end

        context 'renewing employee A' do

          before do
            renewal_benefit_package.renew_member_benefit(census_employees[0])
            family.reload
          end

          let(:family) { employee_A.person.primary_family }
          let(:health_renewals) { family.active_household.hbx_enrollments.renewing.by_health }
          let(:dental_renewals) { family.active_household.hbx_enrollments.renewing.by_dental }

          it 'does renew both health and dental enrollment' do
            expect(health_renewals.size).to eq 1
            expect(health_renewals[0].product).to eq enrollment_1.product.renewal_product
            expect(dental_renewals.size).to eq 1
            expect(dental_renewals[0].product).to eq enrollment_2.product.renewal_product
          end
        end

        context 'renewing employee B' do

          before do
            renewal_benefit_package.renew_member_benefit(census_employees[1])
            family.reload
          end

          let(:family) { employee_B.person.primary_family }
          let(:health_renewals) { family.active_household.hbx_enrollments.renewing.by_health }
          let(:dental_renewals) { family.active_household.hbx_enrollments.by_dental.select(&:renewing_waived?) }

          it 'does renew health coverage and waive dental coverage' do
            expect(health_renewals.size).to eq 1
            expect(health_renewals[0].product).to eq enrollment_3.product.renewal_product
            expect(dental_renewals.size).to eq 1
          end
        end

        context 'renewing employee C' do

          before do
            renewal_benefit_package.renew_member_benefit(census_employees[2])
            family.reload
          end

          let(:family) { employee_C.person.primary_family }
          let(:health_renewals) { family.active_household.hbx_enrollments.by_health.select(&:renewing_waived?) }
          let(:dental_renewals) { family.active_household.hbx_enrollments.renewing.by_dental }

          it 'does renew health coverage and waive dental coverage' do
            expect(health_renewals.size).to eq 1
            expect(dental_renewals.size).to eq 1
            expect(dental_renewals[0].product).to eq enrollment_6.product.renewal_product
          end
        end

        context 'renewing employee D' do

          before do
            renewal_benefit_package.renew_member_benefit(census_employees[3])
            family.reload
          end

          let(:family) { employee_D.person.primary_family }
          let(:passive_renewals) { family.active_household.hbx_enrollments.renewing }
          let(:health_waivers) { family.active_household.hbx_enrollments.by_health.select(&:renewing_waived?) }
          let(:dental_waivers) { family.active_household.hbx_enrollments.by_dental.select(&:renewing_waived?) }

          it 'does renew health coverage and waive dental coverage' do
            expect(passive_renewals).to be_empty
            expect(health_waivers.size).to eq 1
            expect(dental_waivers.size).to eq 1
          end
        end

        context 'renewing employee E' do

          before do
            renewal_benefit_package.renew_member_benefit(census_employees[4])
            family.reload
          end

          let(:family) { employee_E.person.primary_family }
          let(:passive_renewals) { family.active_household.hbx_enrollments.renewing }
          let(:passive_waivers) { family.active_household.hbx_enrollments.select(&:renewing_waived?) }

          it 'does renew health coverage and waive dental coverage' do
            expect(passive_renewals).to be_empty
            expect(passive_waivers).to be_empty
          end
        end

        def create_person(ce, employer_profile)
          person = FactoryBot.create(:person, last_name: ce.last_name, first_name: ce.first_name)
          employee_role = FactoryBot.create(:employee_role, person: person, census_employee: ce, employer_profile: employer_profile)
          ce.update_attributes!({employee_role_id: employee_role.id})
          Family.find_or_build_from_employee_role(employee_role)
          employee_role
        end

        def create_enrollment(family: nil, benefit_group_assignment: nil, employee_role: nil, status: 'coverage_selected', submitted_at: nil, enrollment_kind: 'open_enrollment', effective_date: nil, coverage_kind: 'health')
          benefit_package = benefit_group_assignment.benefit_package
          sponsored_benefit = benefit_package.sponsored_benefit_for(coverage_kind.to_sym)
          FactoryBot.create(:hbx_enrollment,:with_enrollment_members,
                            enrollment_members: [family.primary_applicant],
                            household: family.active_household,
                            coverage_kind: coverage_kind,
                            effective_on: benefit_package.start_on,
                            enrollment_kind: enrollment_kind,
                            kind: "employer_sponsored",
                            submitted_at: submitted_at,
                            employee_role_id: employee_role.id,
                            benefit_sponsorship: benefit_package.benefit_sponsorship,
                            sponsored_benefit_package: benefit_package,
                            sponsored_benefit: sponsored_benefit,
                            benefit_group_assignment_id: benefit_group_assignment.id,
                            product: sponsored_benefit.reference_product,
                            aasm_state: status)
        end
      end
    end
  end

  describe "#notify_enrollment_cancel_or_termination_event", :dbclean => :after_each do
    let(:family) { FactoryBot.build(:family, :with_primary_family_member_and_dependent)}
    let!(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: family.active_household, kind: "employer_sponsored", aasm_state: "coverage_terminated") }
    let!(:glue_event_queue_name) { "#{Rails.application.config.acapi.hbx_id}.#{Rails.application.config.acapi.environment_name}.q.glue.enrollment_event_batch_handler" }

    it "should notify event" do # loud transaction
      expect(hbx_enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                      {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => hbx_enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                       "is_trading_partner_publishable" => true})
      hbx_enrollment.notify_enrollment_cancel_or_termination_event(true)
    end

    it "should notify event, with trading_partner_publishable flag false" do # silent transaction
      expect(hbx_enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                      {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => hbx_enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                       "is_trading_partner_publishable" => false})
      hbx_enrollment.notify_enrollment_cancel_or_termination_event(false)
    end
  end

end


describe HbxEnrollment,"reinstate and change end date", type: :model, :dbclean => :around_each do

  context "Terminated enrollment re-instatement" do
    let(:current_date) { Date.new(TimeKeeper.date_of_record.year, 6, 1) }
    let(:effective_on_date)         { Date.new(TimeKeeper.date_of_record.year, 3, 1) }
    let(:terminated_on_date)        {effective_on_date + 10.days}

    before do
      TimeKeeper.set_date_of_record_unprotected!(current_date)
    end

    context "for Individual market" do
      let(:ivl_family)        { FactoryBot.create(:family, :with_primary_family_member) }

      let(:ivl_enrollment)    do
        ivl_family.latest_household.hbx_enrollments.create!(
          household: ivl_family.latest_household,
          coverage_kind: "health",
          effective_on: effective_on_date,
          enrollment_kind: "open_enrollment",
          kind: "individual",
          aasm_state: "coverage_terminated",
          terminated_on: terminated_on_date
        )
      end

      it "should re-instate enrollment" do
        ivl_enrollment.reinstate
        reinstated_enrollment = ivl_family.active_household.hbx_enrollments.detect(&:coverage_selected?)

        expect(reinstated_enrollment.present?).to be_truthy
        expect(reinstated_enrollment.workflow_state_transitions.where(:to_state => 'coverage_reinstated').present?).to be_truthy
        expect(reinstated_enrollment.effective_on).to eq terminated_on_date.next_day
      end
    end

    context "for SHOP market" do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_on) { current_effective_date }
      let(:hired_on) { TimeKeeper.date_of_record - 3.months }
      let(:employee_created_at) { hired_on }
      let(:employee_updated_at) { employee_created_at }

      let(:person) {FactoryBot.create(:person, first_name: 'John', last_name: 'Smith', dob: '1966-10-10'.to_date, ssn: '123456789')}
      let(:shop_family) {FactoryBot.create(:family, :with_primary_family_member_and_dependent)}
      let!(:sponsored_benefit) {benefit_sponsorship.benefit_applications.first.benefit_packages.first.health_sponsored_benefit}
      let!(:update_sponsored_benefit) {sponsored_benefit.update_attributes(product_package_kind: :single_product)}

      let(:aasm_state) { :active }
      let(:census_dependents) { nil }
      let(:census_employee) do
        create(
          :census_employee,
          :with_active_assignment,
          benefit_sponsorship: benefit_sponsorship,
          employer_profile: benefit_sponsorship.profile,
          benefit_group: current_benefit_package,
          hired_on: hired_on,
          created_at: employee_created_at,
          updated_at: employee_updated_at,
          census_dependents: census_dependents
        )
      end
      let(:employee_role) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
      let(:enrollment_kind) { "open_enrollment" }
      let(:special_enrollment_period_id) { nil }
      let!(:shop_enrollment) do
        shop_family.latest_household.hbx_enrollments.create(
          coverage_kind: "health",
          effective_on: effective_on,
          enrollment_kind: enrollment_kind,
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          product: sponsored_benefit.reference_product,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          aasm_state: "coverage_selected"
        )
      end

      before do
        census_employee.update_attributes(employee_role_id: employee_role.id)
        census_employee.terminate_employment(effective_on + 1.days)
        shop_enrollment.reload
        census_employee.reload
      end

      it "should have terminated enrollment & cenuss employee" do
        expect(shop_enrollment.coverage_termination_pending?).to be_truthy
        expect(census_employee.employee_termination_pending?).to be_truthy
      end

      context 'when re-instated' do
        before do
          census_employee.terminate_employee_role!
          shop_enrollment.reinstate
        end

        it "should have re-instate enrollment" do
          reinstated_enrollment = shop_family.active_household.hbx_enrollments.detect(&:coverage_enrolled?)

          expect(reinstated_enrollment.present?).to be_truthy
          expect(reinstated_enrollment.workflow_state_transitions.where(:to_state => 'coverage_reinstated').present?).to be_truthy
          expect(reinstated_enrollment.effective_on).to eq shop_enrollment.terminated_on.next_day
        end

        it 'should re-instate census employee' do
          census_employee.reload
          expect(census_employee.employee_role_linked?).to be_truthy
        end
      end

      context 'when dependent record is updated' do
        let(:dependent) { shop_family.family_members.where(is_primary_applicant: false)[0] }
        let(:dependent_person) { dependent.person }
        let!(:census_dependent){ build(:census_dependent, first_name: dependent_person.first_name, last_name: dependent_person.last_name, dob: dependent_person.dob, ssn: dependent_person.ssn)}
        let(:census_dependents) { [census_dependent] }
        let!(:shop_enrollment) do
          create(
            :hbx_enrollment,
            :with_enrollment_members,
            coverage_kind: "health",
            product: sponsored_benefit.reference_product,
            kind: "employer_sponsored",
            enrollment_kind: enrollment_kind,
            household: shop_family.active_household,
            aasm_state: 'coverage_selected',
            effective_on: effective_on,
            rating_area_id: current_benefit_package.benefit_application.recorded_rating_area_id,
            sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
            sponsored_benefit_package_id: current_benefit_package.id,
            benefit_sponsorship_id: benefit_sponsorship.id,
            benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
            hbx_enrollment_members: [hbx_enrollment_member1, hbx_enrollment_member2],
            employee_role_id: employee_role.id
          )
        end

        let(:hbx_enrollment_member1) do
          build(
            :hbx_enrollment_member,
            applicant_id: shop_family.primary_applicant.id,
            is_subscriber: true,
            eligibility_date: Date.today
          )
        end

        let(:hbx_enrollment_member2) do
          build(
            :hbx_enrollment_member,
            applicant_id: dependent.id,
            is_subscriber: false,
            eligibility_date: Date.today
          )
        end

        before do
          census_employee.terminate_employee_role!
          dependent = census_employee.reload.census_dependents[0]
          dependent.update_attributes(first_name: "Snow11", last_name: 'John11')
          shop_enrollment.reinstate
        end

        it 'should update dependent record' do
          expect(census_employee.reload.census_dependents[0].first_name).not_to eq 'Snow11'
          expect(census_employee.reload.census_dependents[0].last_name).not_to eq 'John11'
        end

        it 'should not create duplicate dependent records' do
          expect(census_employee.reload.census_dependents.size).to eq 1
        end
      end
    end
  end

  ###########

  describe "#is_reinstated_enrollment?" do
    let(:hbx_enrollment) { HbxEnrollment.new(kind: 'employer_sponsored') }
    let(:workflow_state_transition) {FactoryBot.build(:workflow_state_transition,:from_state => "coverage_reinstated", :to_state => "coverage_selected")}
    context 'when enrollment has been reinstated' do
      it "should have reinstated enrollmentt" do
        allow(hbx_enrollment).to receive(:workflow_state_transitions).and_return([workflow_state_transition])
        expect(hbx_enrollment.is_reinstated_enrollment?).to be_truthy
      end
    end
    context 'when enrollment has not been reinstated' do
      it "should have reinstated enrollmentt" do
        allow(hbx_enrollment).to receive(:workflow_state_transitions).and_return([])
        expect(hbx_enrollment.is_reinstated_enrollment?).to be_falsey
      end
    end
  end

  describe "#can_be_reinstated?" do

    context "for Individual market" do
      let(:ivl_family)        { FactoryBot.create(:family, :with_primary_family_member) }

      let(:ivl_enrollment)    do
        ivl_family.latest_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: TimeKeeper.date_of_record.last_year.beginning_of_year,
          enrollment_kind: "open_enrollment",
          kind: "individual",
          aasm_state: "coverage_terminated",
          terminated_on: TimeKeeper.date_of_record.last_year.end_of_year
        )
      end

      it "enrollment termianted previous year can't be reinstated?" do
        expect(ivl_enrollment.can_be_reinstated?).to be_falsey
      end

      it "enrollment termianted during current year can be reinstated?" do
        ivl_enrollment.update_attributes(effective_on: TimeKeeper.date_of_record.beginning_of_year, terminated_on: TimeKeeper.date_of_record.end_of_month)
        ivl_enrollment.reload
        expect(ivl_enrollment.can_be_reinstated?).to be_truthy
      end

    end

    context "for SHOP market" do

      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_on) { current_effective_date }
      let(:hired_on) { TimeKeeper.date_of_record - 3.months }
      let(:employee_created_at) { hired_on }
      let(:employee_updated_at) { employee_created_at }

      let(:person) {FactoryBot.create(:person, first_name: 'John', last_name: 'Smith', dob: '1966-10-10'.to_date, ssn: '123456789')}
      let(:shop_family) {FactoryBot.create(:family, :with_primary_family_member)}
      let!(:sponsored_benefit) {benefit_sponsorship.benefit_applications.first.benefit_packages.first.health_sponsored_benefit}
      let!(:update_sponsored_benefit) {sponsored_benefit.update_attributes(product_package_kind: :single_product)}

      let(:aasm_state) { :active }
      let(:census_employee) do
        create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, created_at: employee_created_at,
                                                          updated_at: employee_updated_at)
      end
      let(:employee_role) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
      let(:enrollment_kind) { "open_enrollment" }
      let(:special_enrollment_period_id) { nil }
      let!(:enrollment) do
        shop_family.latest_household.hbx_enrollments.create!(
          coverage_kind: "health",
          effective_on: effective_on,
          enrollment_kind: enrollment_kind,
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          product: sponsored_benefit.reference_product,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id
        )
      end


      context "reinstating coverage_terminated enrollment" do
        context 'reinstated effective date falls outside active plan year' do
          before do
            enrollment.update_attributes(aasm_state: 'coverage_terminated', terminated_on: current_benefit_package.benefit_application.end_on)
            enrollment.reload
          end

          it "should return false" do
            expect(enrollment.can_be_reinstated?).to be_falsey
          end
        end

        context 'reinstated effective date falls with in range of active plan year' do
          before do
            enrollment.update_attributes(aasm_state: 'coverage_terminated', terminated_on: current_benefit_package.benefit_application.end_on - 1.month)
            enrollment.reload
          end

          it "should return true" do
            expect(enrollment.can_be_reinstated?).to be_truthy
          end
        end
      end

      context "reinstating coverage_terminated pending enrollment" do
        context 'reinstated effective date falls outside active plan year' do
          before do
            enrollment.update_attributes(aasm_state: 'coverage_termination_pending', terminated_on: current_benefit_package.benefit_application.end_on)
            enrollment.reload
          end

          it "should return false" do
            expect(enrollment.can_be_reinstated?).to be_falsey
          end
        end

        context 'reinstated effective date falls with in range of active plan year' do
          before do
            enrollment.update_attributes(aasm_state: 'coverage_termination_pending', terminated_on: current_benefit_package.benefit_application.end_on - 1.month)
            enrollment.reload
          end

          it "should return true" do
            expect(enrollment.can_be_reinstated?).to be_truthy
          end
        end
      end

      context 'for reinstated enrollment no active coverage offering by employer' do

        before do
          current_benefit_package.benefit_application.update_attributes(aasm_state: :terminated)
          enrollment.update_attributes(aasm_state: 'coverage_terminated', terminated_on: current_benefit_package.benefit_application.end_on - 1.month)
          enrollment.reload
        end

        it "should return true" do
          expect(enrollment.can_be_reinstated?).to be_falsey
        end
      end

      context "reinstating employer sponsored enrollment for cobra employee" do

        before do
          enrollment.update_attributes(aasm_state: 'coverage_terminated', terminated_on: current_benefit_package.benefit_application.end_on - 1.month)
          enrollment.employee_role.census_employee.update_attributes(aasm_state: 'cobra_linked', cobra_begin_date: TimeKeeper.date_of_record)
        end

        it "should return false" do
          expect(enrollment.can_be_reinstated?).to be_falsey
        end
      end

      context "reinstating cobra enrollment for active employee" do

        before do
          enrollment.update_attributes(kind: 'employer_sponsored_cobra', aasm_state: 'coverage_terminated', terminated_on: current_benefit_package.benefit_application.end_on - 1.month)
        end

        it "should return false" do
          expect(enrollment.can_be_reinstated?).to be_falsey
        end

      end
    end
  end

  describe "#has_active_or_term_exists_for_reinstated_date?" do

    context "for Individual market" do
      let(:ivl_family)        { FactoryBot.create(:family, :with_primary_family_member) }

      let(:ivl_enrollment) do
        ivl_family.active_household.hbx_enrollments.create(
          coverage_kind: "health",
          effective_on: TimeKeeper.date_of_record.last_year.beginning_of_month,
          enrollment_kind: "open_enrollment",
          kind: "individual",
          aasm_state: "coverage_terminated",
          terminated_on: TimeKeeper.date_of_record.end_of_month
        )
      end

      let!(:ivl_enrollment2) do
        ivl_family.active_household.hbx_enrollments.create(
          coverage_kind: "health",
          enrollment_kind: "open_enrollment",
          kind: "individual",
          aasm_state: "coverage_selected",
          effective_on: TimeKeeper.date_of_record.end_of_month + 1.day
        )
      end


      it "should return true if active enrollment exists for reinstated date " do
        expect(ivl_enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return true if termianted enrollment exists for reinstated date" do
        ivl_enrollment2.update_attributes(effective_on: TimeKeeper.date_of_record.end_of_month + 1.day, aasm_state: "coverage_terminated")
        ivl_enrollment2.reload
        expect(ivl_enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return true if future active enrollment exists" do
        ivl_enrollment2.update_attributes(aasm_state: "coverage_selected", effective_on: TimeKeeper.date_of_record.beginning_of_month + 1.months)
        ivl_enrollment2.reload
        expect(ivl_enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return false if no active enrollment exists for reinstated date" do
        ivl_enrollment2.update_attributes(effective_on: TimeKeeper.date_of_record.end_of_month + 1.day, aasm_state: "coverage_canceled")
        ivl_enrollment2.reload
        expect(ivl_enrollment.has_active_or_term_exists_for_reinstated_date?).to be_falsey
      end

    end

    context "for SHOP market" do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_on) { current_effective_date }
      let(:hired_on) { TimeKeeper.date_of_record - 3.months }
      let(:employee_created_at) { hired_on }
      let(:employee_updated_at) { employee_created_at }

      let(:person) {FactoryBot.create(:person, first_name: 'John', last_name: 'Smith', dob: '1966-10-10'.to_date, ssn: '123456789')}
      let(:shop_family) {FactoryBot.create(:family, :with_primary_family_member)}
      let!(:sponsored_benefit) {benefit_sponsorship.benefit_applications.first.benefit_packages.first.health_sponsored_benefit}
      let!(:update_sponsored_benefit) {sponsored_benefit.update_attributes(product_package_kind: :single_product)}

      let(:aasm_state) { :active }
      let(:census_employee) do
        create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, created_at: employee_created_at,
                                                          updated_at: employee_updated_at)
      end
      let(:employee_role) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: census_employee.hired_on, census_employee_id: census_employee.id) }
      let(:enrollment_kind) { "open_enrollment" }
      let(:special_enrollment_period_id) { nil }
      let!(:enrollment) do
        shop_family.latest_household.hbx_enrollments.create(
          coverage_kind: "health",
          effective_on: effective_on,
          enrollment_kind: enrollment_kind,
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          product: sponsored_benefit.reference_product,
          aasm_state: "coverage_terminated",
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          terminated_on: effective_on.end_of_month
        )
      end
      let!(:enrollment2) do
        shop_family.latest_household.hbx_enrollments.create(
          coverage_kind: "health",
          effective_on: TimeKeeper.date_of_record.next_month.beginning_of_month,
          enrollment_kind: enrollment_kind,
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
          employee_role_id: employee_role.id,
          product: sponsored_benefit.reference_product,
          aasm_state: "coverage_selected",
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id
        )

      end

      it "should return true if active enrollment exists for reinstated date " do
        expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return true if termianted enrollment exists for reinstated date" do
        enrollment2.update_attributes(effective_on: effective_on.end_of_month + 1.day, aasm_state: "coverage_terminated")
        enrollment2.reload
        expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return true if future active enrollment exists" do
        enrollment2.update_attributes(effective_on: TimeKeeper.date_of_record.next_month.beginning_of_month + 1.month)
        enrollment2.reload
        expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
      end

      it "should return false if no active enrollment exists for reinstated date" do
        enrollment2.update_attributes(effective_on: effective_on.end_of_month + 1.day, aasm_state: "coverage_canceled")
        enrollment2.reload
        expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_falsey
      end

      context "with employer_sponsored & active cobra enrollment" do

        it "should return true if active enrollment exists for reinstated date " do
          enrollment2.update_attributes(kind: "employer_sponsored_cobra")
          enrollment2.reload
          expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
        end

        it "should return true if future active enrollment exists" do
          enrollment2.update_attributes(kind: "employer_sponsored_cobra", effective_on: effective_on.end_of_month + 1.day)
          enrollment2.reload
          expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_truthy
        end

        it "should return false if no active enrollment exists for reinstated date" do
          enrollment2.update_attributes(kind: "employer_sponsored_cobra", effective_on: effective_on.end_of_month + 1.day, aasm_state: "coverage_canceled")
          enrollment2.reload
          expect(enrollment.has_active_or_term_exists_for_reinstated_date?).to be_falsey
        end
      end

      context "enrollment from two mutiple employers." do

        include_context "setup benefit market with market catalogs and product packages"
        include_context "setup initial benefit application"

        let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
        let(:effective_on) { current_effective_date }
        let(:hired_on) { TimeKeeper.date_of_record - 3.months }
        let(:employee_created_at) { hired_on }
        let(:employee_updated_at) { employee_created_at }

        let!(:sponsored_benefit2) {benefit_sponsorship.benefit_applications.first.benefit_packages.first.health_sponsored_benefit}
        let!(:update_sponsored_benefit) {sponsored_benefit.update_attributes(product_package_kind: :single_product)}

        let(:aasm_state) { :active }
        let(:census_employee2) do
          create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, created_at: employee_created_at,
                                                            updated_at: employee_updated_at)
        end
        let(:employee_role2) { FactoryBot.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: census_employee2.hired_on, census_employee_id: census_employee2.id) }
        let(:enrollment_kind) { "open_enrollment" }
        let(:special_enrollment_period_id) { nil }

        let!(:enrollment3) do
          shop_family.latest_household.hbx_enrollments.create!(
            coverage_kind: "health",
            effective_on: effective_on.end_of_month,
            enrollment_kind: enrollment_kind,
            kind: "employer_sponsored",
            benefit_sponsorship_id: benefit_sponsorship.id,
            sponsored_benefit_package_id: current_benefit_package.id,
            sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
            employee_role_id: employee_role2.id,
            product: sponsored_benefit2.reference_product,
            aasm_state: "coverage_selected",
            benefit_group_assignment_id: census_employee2.active_benefit_group_assignment.id,
            terminated_on: effective_on.end_of_month
          )
        end


        it "should return false when reinstated date enrollment exits with different employer " do
          expect(enrollment3.has_active_or_term_exists_for_reinstated_date?).to be_falsey
        end
      end
    end
  end

  context '.display_make_changes_for_shop?' do
    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let!(:household) { FactoryBot.create(:household, family: family) }
    let(:hbx_profile) {FactoryBot.create(:hbx_profile)}
    let(:benefit_sponsorship) { FactoryBot.create(:benefit_sponsorship, :open_enrollment_coverage_period, hbx_profile: hbx_profile) }
    let!(:sponsored_benefit) { double }

    let(:benefit_coverage_period) { hbx_profile.benefit_sponsorship.benefit_coverage_periods.first }
    let(:sep) {SpecialEnrollmentPeriod.new(effective_on: TimeKeeper.date_of_record, start_on: TimeKeeper.date_of_record, end_on: TimeKeeper.date_of_record + 1)}
    let!(:enrollment) do
      FactoryBot.create(
        :hbx_enrollment,
        household: family.active_household,
        coverage_kind: "health",
        effective_on: TimeKeeper.date_of_record.beginning_of_year,
        aasm_state: 'coverage_selected'
      )
    end
    let(:employee_role_double) { double(id: 1) }

    if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
      context 'for ivl' do
        before do
          allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
          allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
          allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(benefit_coverage_period)
          allow(enrollment).to receive(:sponsored_benefit_package).and_return(sponsored_benefit)
          allow(sponsored_benefit).to receive(:open_enrollment_contains?).with(TimeKeeper.date_of_record).and_return(true)
          enrollment.kind = 'individual'
          enrollment.save
        end

        it 'should return false' do
          expect(enrollment.display_make_changes_for_shop?).to be_falsey
        end
      end
    end

    context 'for shop' do
      before :each do
        allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
        allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
        allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(benefit_coverage_period)
        allow(enrollment).to receive(:sponsored_benefit_package).and_return(sponsored_benefit)
        allow(enrollment).to receive(:employee_role).and_return(employee_role_double)
      end

      context "can_enroll_as_new_hire?" do
        before do
          # False for "or" statements
          allow(enrollment.family).to receive(:enrollment_is_not_most_recent_sep_enrollment?).with(enrollment).and_return(false)
          allow(sponsored_benefit).to receive(:open_enrollment_contains?).with(TimeKeeper.date_of_record).and_return(false)
        end

        it "should display make changes if true" do
          allow(enrollment.employee_role).to receive(:can_enroll_as_new_hire?).and_return(true)
          expect(enrollment.display_make_changes_for_shop?).to eq(true)
        end

        it "should not display make changes if false" do
          allow(enrollment.employee_role).to receive(:can_enroll_as_new_hire?).and_return(false)
          expect(enrollment.display_make_changes_for_shop?).to be_falsey
        end
      end

      context "can enroll with active shop sep??" do
        before do
          allow(enrollment.family).to receive(:earliest_effective_shop_sep).and_return(sep)
          allow(sponsored_benefit).to receive(:effective_period).and_return(sep.effective_on..sep.effective_on + 1.month)
        end

        it 'should return true if enr is active and is not in open enrollment period and family has active shop sep which falls under benefit package effective period' do
          expect(enrollment.display_make_changes_for_shop?).to eq(true)
        end
      end

      context 'make changes and view detail buttons on enrollment tile' do
        it 'should not be visible when aasm_state is coverage_canceled' do
          allow(enrollment).to receive(:aasm_state).and_return('coverage_canceled')
          expect(enrollment.display_make_changes_for_shop?).to be_falsey
        end

        it 'should not be visible when aasm_state is coverage_expired' do
          allow(enrollment).to receive(:aasm_state).and_return('coverage_expired')
          expect(enrollment.display_make_changes_for_shop?).to be_falsey
        end

        it 'should not be visible when aasm_state is coverage_terminated' do
          allow(enrollment).to receive(:aasm_state).and_return('coverage_terminated')
          expect(enrollment.display_make_changes_for_shop?).to be_falsey
        end
      end
    end
  end

  context '.display_make_changes_for_ivl?' do
    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let!(:household) { FactoryBot.create(:household, family: family) }
    let(:hbx_profile) {FactoryBot.create(:hbx_profile)}
    let(:benefit_sponsorship) { FactoryBot.create(:benefit_sponsorship, :open_enrollment_coverage_period, hbx_profile: hbx_profile) }
    let(:benefit_coverage_period) { hbx_profile.benefit_sponsorship.benefit_coverage_periods.first }
    let(:sep) {SpecialEnrollmentPeriod.new(effective_on: TimeKeeper.date_of_record, start_on: TimeKeeper.date_of_record, end_on: TimeKeeper.date_of_record + 1)}
    let!(:enrollment) do
      FactoryBot.create(
        :hbx_enrollment,
        household: family.active_household,
        coverage_kind: "health",
        effective_on: TimeKeeper.date_of_record.beginning_of_year,
        aasm_state: 'coverage_selected'
      )
    end

    before :each do
      allow(HbxProfile).to receive(:current_hbx).and_return hbx_profile
      allow(hbx_profile).to receive(:benefit_sponsorship).and_return benefit_sponsorship
      allow(benefit_sponsorship).to receive(:current_benefit_period).and_return(benefit_coverage_period)
    end

    context 'for shop' do

      before do
        enrollment.kind = 'employer_sponsored'
        enrollment.save
      end

      it 'should return false' do
        expect(enrollment.display_make_changes_for_ivl?).to be_falsey
      end
    end

    if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
      context 'for ivl' do

        before do
          enrollment.kind = 'individual'
          enrollment.save
        end

        context 'family with active sep' do
          before do
            allow(family).to receive(:latest_ivl_sep).and_return sep
          end

          it 'should return true' do
            expect(enrollment.display_make_changes_for_ivl?).to be_truthy
          end
        end

        context 'under open enrollment period' do

          before do
            allow(family).to receive(:is_under_ivl_open_enrollment?).and_return true
          end

          it 'should return true' do
            expect(enrollment.display_make_changes_for_ivl?).to be_truthy
          end
        end
      end
    end
  end

  describe "#reterm_enrollment_with_earlier_date" do
    let(:user) { FactoryBot.create(:user, roles: ["hbx_staff"]) }
    let!(:person) { FactoryBot.create(:person)}
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let!(:household) { FactoryBot.create(:household, family: family) }
    let!(:enrollment) do
      family.active_household.hbx_enrollments.create(
        coverage_kind: "health",
        kind: 'employer_sponsored',
        effective_on: TimeKeeper.date_of_record.last_month.beginning_of_month,
        terminated_on: TimeKeeper.date_of_record.end_of_month,
        aasm_state: 'coverage_termination_pending'
      )
    end
    let!(:glue_event_queue_name) { "#{Rails.application.config.acapi.hbx_id}.#{Rails.application.config.acapi.environment_name}.q.glue.enrollment_event_batch_handler" }

    context "shop enrollment" do
      context "enrollment that already terminated with past date" do
        context "with new past or current termination date" do
          it "should update enrollment with new end date and notify enrollment" do
            expect(enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                         "is_trading_partner_publishable" => false})
            enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq "coverage_terminated"
            expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record
          end
        end

        context "new term date greater than current termination date" do
          it "return false" do
            expect(enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record + 2.months, false)).to eq false
          end
        end
      end

      context "enrollment that already terminated with future date" do
        context "with new future termination date" do
          it "should update enrollment with new end date and notify enrollment" do
            enrollment.update_attributes(terminated_on: TimeKeeper.date_of_record.next_month.end_of_month)
            expect(enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                         "is_trading_partner_publishable" => false})
            enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record + 1.day, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq "coverage_termination_pending"
            expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record + 1.day
          end
        end
      end

      context "enrollment that has effective date older than prior year date" do
        it "should return false" do
          enrollment.effective_on = Date.new(2018,1,1)
          enrollment.save
          expect(enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record, false)).to eq false
        end
      end
    end

    context "IVL enrollment" do

      before do
        enrollment.kind = "individual"
        enrollment.save
      end

      context "enrollment that already terminated with past date" do
        context "with new past or current termination date" do
          it "should update enrollment with new end date and notify enrollment" do
            expect(enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                         "is_trading_partner_publishable" => false})
            enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq "coverage_terminated"
            expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record
          end
        end
      end

      context "enrollment that already terminated with future date" do
        context "with new future termination date" do
          it "should update enrollment with new end date and notify enrollment" do
            enrollment.update_attributes(terminated_on: TimeKeeper.date_of_record.next_month.end_of_month)
            expect(enrollment).to receive(:notify).with("acapi.info.events.hbx_enrollment.terminated",
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                         "is_trading_partner_publishable" => false})
            enrollment.reterm_enrollment_with_earlier_date(TimeKeeper.date_of_record + 1.day, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq "coverage_terminated"
            expect(enrollment.terminated_on).to eq TimeKeeper.date_of_record + 1.day
          end
        end
      end
    end
  end

  describe '#cancel_terminated_enrollment' do
    let(:user) { FactoryBot.create(:user, roles: ['hbx_staff']) }
    let!(:person) { FactoryBot.create(:person)}
    let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person)}
    let!(:household) { FactoryBot.create(:household, family: family) }
    let!(:enrollment) do
      family.active_household.hbx_enrollments.create(
        coverage_kind: 'health',
        kind: 'employer_sponsored',
        effective_on: TimeKeeper.date_of_record.last_month.beginning_of_month,
        terminated_on: TimeKeeper.date_of_record.end_of_month,
        aasm_state: 'coverage_termination_pending'
      )
    end
    let!(:glue_event_queue_name) { "#{Rails.application.config.acapi.hbx_id}.#{Rails.application.config.acapi.environment_name}.q.glue.enrollment_event_batch_handler" }

    context 'shop enrollment' do
      context 'enrollment that already terminated with past date' do
        context 'with new termination date == enrollment effective date' do

          before do
            enrollment.update_attributes(aasm_state: 'coverage_terminated', terminated_on: TimeKeeper.date_of_record - 1.day)
            enrollment.reload
          end
          it 'should cancel enrollment' do
            expect(enrollment).to receive(:notify).with('acapi.info.events.hbx_enrollment.terminated',
                                                        {:reply_to => glue_event_queue_name, 'hbx_enrollment_id' => enrollment.hbx_id, 'enrollment_action_uri' => 'urn:openhbx:terms:v1:enrollment#terminate_enrollment',
                                                         'is_trading_partner_publishable' => false})
            enrollment.cancel_terminated_enrollment(TimeKeeper.date_of_record.last_month.beginning_of_month, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq 'coverage_canceled'
            expect(enrollment.terminated_on).to eq nil
            expect(enrollment.termination_submitted_on).to eq nil
            expect(enrollment.terminate_reason).to eq nil
          end
        end
      end

      context 'enrollment that already terminated with future date' do
        context 'with new termination date == enrollment effective date' do
          it 'should cancel enrollment' do
            expect(enrollment).to receive(:notify).with('acapi.info.events.hbx_enrollment.terminated',
                                                        {:reply_to => glue_event_queue_name, 'hbx_enrollment_id' => enrollment.hbx_id, 'enrollment_action_uri' => 'urn:openhbx:terms:v1:enrollment#terminate_enrollment',
                                                         'is_trading_partner_publishable' => false})
            enrollment.cancel_terminated_enrollment(TimeKeeper.date_of_record.last_month.beginning_of_month, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq 'coverage_canceled'
            expect(enrollment.terminated_on).to eq nil
            expect(enrollment.termination_submitted_on).to eq nil
            expect(enrollment.terminate_reason).to eq nil
          end
        end
      end
    end

    context 'IVL enrollment' do

      before do
        enrollment.kind = 'individual'
        enrollment.aasm_state = 'coverage_terminated'
        enrollment.save
      end

      context 'enrollment that already terminated with past date' do
        context 'with new termination date == enrollment effective date' do
          it 'should cancel enrollment' do
            enrollment.update_attributes(terminated_on: TimeKeeper.date_of_record - 1.day)
            expect(enrollment).to receive(:notify).with('acapi.info.events.hbx_enrollment.terminated',
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, 'enrollment_action_uri' => 'urn:openhbx:terms:v1:enrollment#terminate_enrollment',
                                                         'is_trading_partner_publishable' => false})
            enrollment.cancel_terminated_enrollment(TimeKeeper.date_of_record.last_month.beginning_of_month, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq 'coverage_canceled'
            expect(enrollment.terminated_on).to eq nil
            expect(enrollment.termination_submitted_on).to eq nil
            expect(enrollment.terminate_reason).to eq nil
          end
        end
      end

      context 'enrollment that already terminated with future date' do
        context 'with new termination date == enrollment effective date' do
          it 'should cancel enrollment' do
            expect(enrollment).to receive(:notify).with('acapi.info.events.hbx_enrollment.terminated',
                                                        {:reply_to => glue_event_queue_name, "hbx_enrollment_id" => enrollment.hbx_id, "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                                                         "is_trading_partner_publishable" => false})
            enrollment.cancel_terminated_enrollment(TimeKeeper.date_of_record.last_month.beginning_of_month, false)
            enrollment.reload
            expect(enrollment.aasm_state).to eq 'coverage_canceled'
            expect(enrollment.terminated_on).to eq nil
            expect(enrollment.termination_submitted_on).to eq nil
            expect(enrollment.terminate_reason).to eq nil
          end
        end
      end
    end
  end
end
