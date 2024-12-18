# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe EnrollmentShopping::EnrollmentBuilder, dbclean: :after_each do

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees with benefits"

  let(:dental_sponsored_benefit) { true }
  let(:product_kinds)  { [:health, :dental] }
  let(:roster_size) { 2 }
  let(:start_on) { TimeKeeper.date_of_record.prev_month.beginning_of_month }
  let(:effective_period) {start_on..start_on.next_year.prev_day}

  let(:ce) { benefit_sponsorship.census_employees.non_business_owner.first }

  let!(:family) do
    person = FactoryBot.create(:person, last_name: ce.last_name, first_name: ce.first_name)
    employee_role = FactoryBot.create(:employee_role, person: person, census_employee: ce, employer_profile: abc_profile)
    ce.update_attributes({employee_role: employee_role})
    Family.find_or_build_from_employee_role(employee_role)
  end

  let(:person) { family.primary_applicant.person }
  let(:effective_on) { start_on }
  let(:is_qle?) { false }
  let(:family_member_ids) { family.family_members.map(&:id) }
  let(:coverage_household) { family.active_household.immediate_family_coverage_household }
  let(:employee_role) { person.active_employee_roles.first }

  let(:enrollment_builder) { EnrollmentShopping::EnrollmentBuilder.new(coverage_household, employee_role, coverage_kind) }

  shared_examples_for "build new enrollment of state" do |state|

    context "when employee shopping" do

      shared_examples_for "under open enrollment period" do |coverage_kind|
        let(:coverage_kind) { coverage_kind }
        let(:start_on) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
        let(:current_effective_date) { start_on }
        let(:open_enrollment_start_on) { TimeKeeper.date_of_record }
        let(:open_enrollment_end_on) { TimeKeeper.date_of_record + 10.days}
        let(:open_enrollment_period) { open_enrollment_start_on..open_enrollment_end_on }
        let(:aasm_state) { :enrollment_open }
        let(:waiver_subject) { enrollment_builder.build_new_waiver_enrollment(is_qle: is_qle?, optional_effective_on: effective_on, waiver_reason: "this is waiver reason") }
        let(:enrolled_subject) { enrollment_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: is_qle?, optional_effective_on: effective_on) }

        subject(:enrollment) do
          state == "waiver" ? waiver_subject : enrolled_subject
        end

        before :all do
          DatabaseCleaner.clean
        end

        before :all do
          DatabaseCleaner.clean
        end

        it "should build a new #{coverage_kind} enrollment" do
          expect(enrollment.valid?).to be_truthy
          expect(enrollment.coverage_kind).to eq coverage_kind
          expect(enrollment.effective_on).to eq effective_on
          expect(enrollment.enrollment_kind).to eq 'open_enrollment'
          expect(enrollment.hbx_enrollment_members).to be_present
          expect(enrollment.hbx_enrollment_members.collect(&:applicant_id)).to eq family_member_ids
          expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
          expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
          expect(enrollment.coverage_kind).to eq coverage_kind
          expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
        end
      end

      it_behaves_like "under open enrollment period", "health"
      it_behaves_like "under open enrollment period", "dental"

      context "under new hire enrollment period" do

        shared_examples_for "with past hired on date" do |coverage_kind|
          let(:current_effective_date) { start_on }
          let(:open_enrollment_start_on) { TimeKeeper.date_of_record }
          let(:open_enrollment_end_on) { TimeKeeper.date_of_record + 10.days}
          let(:open_enrollment_period) { open_enrollment_start_on..open_enrollment_end_on }
          let(:coverage_kind) { coverage_kind }
          let(:start_on) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
          let(:aasm_state) { :active }

          let!(:ce) do
            census_employee = benefit_sponsorship.census_employees.non_business_owner.first
            census_employee.update(hired_on: TimeKeeper.date_of_record - 2.years)
            census_employee
          end

          let(:waiver_subject) { enrollment_builder.build_new_waiver_enrollment(is_qle: false, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
          let(:enrolled_subject) { enrollment_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: false, optional_effective_on: nil) }

          subject(:enrollment) do
            state == "waiver" ? waiver_subject : enrolled_subject
          end

          it "should build a new #{coverage_kind} enrollment with effective date same as plan year start date" do
            expect(enrollment.valid?).to be_truthy
            expect(enrollment.coverage_kind).to eq coverage_kind
            expect(enrollment.effective_on).to eq start_on
            expect(enrollment.enrollment_kind).to eq 'open_enrollment'
            expect(enrollment.hbx_enrollment_members).to be_present
            expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
            expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
            expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
            expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
          end
        end

        it_behaves_like "with past hired on date", "health"
        it_behaves_like "with past hired on date", "dental"

        shared_examples_for "with current hired on date" do |coverage_kind|
          let(:coverage_kind) { coverage_kind }
          let(:hired_on) { TimeKeeper.date_of_record - 2.days }

          let(:earliest_effective_on) do
            hired_on.mday == 1 ? hired_on : hired_on.next_month.beginning_of_month
          end

          let!(:ce) do
            census_employee = benefit_sponsorship.census_employees.non_business_owner.first
            census_employee.update(hired_on: hired_on)
            census_employee
          end

          let(:waiver_subject) { enrollment_builder.build_new_waiver_enrollment(is_qle: false, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
          let(:enrolled_subject) { enrollment_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: false, optional_effective_on: nil) }

          subject(:enrollment) do
            state == "waiver" ? waiver_subject : enrolled_subject
          end

          it "should build a new #{coverage_kind} enrollment with effective date beginning of next month" do
            expect(enrollment.valid?).to be_truthy
            expect(enrollment.coverage_kind).to eq coverage_kind
            expect(enrollment.effective_on).to eq earliest_effective_on
            expect(enrollment.enrollment_kind).to eq 'open_enrollment'
            expect(enrollment.hbx_enrollment_members).to be_present
            expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
            expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
            expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
            expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
          end
        end

        it_behaves_like "with current hired on date", "health"
        it_behaves_like "with current hired on date", "dental"
      end

      shared_examples_for "under special enrollment period" do |coverage_kind|
        let(:coverage_kind) { coverage_kind }
        let(:start_on) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
        let(:current_effective_date) { start_on }
        let(:open_enrollment_start_on) { TimeKeeper.date_of_record }
        let(:open_enrollment_end_on) { TimeKeeper.date_of_record + 10.days}
        let(:open_enrollment_period) { open_enrollment_start_on..open_enrollment_end_on }
        let(:aasm_state) { :active }
        let(:qualifying_life_event_kind) { FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date) }
        let(:qle_on) { TimeKeeper.date_of_record - 2.days }

        let!(:special_enrollment_period) do
          special_enrollment = family.special_enrollment_periods.build({
                                                                         qle_on: qle_on,
                                                                         effective_on_kind: "date_of_event"
                                                                       })

          special_enrollment.qualifying_life_event_kind = qualifying_life_event_kind
          special_enrollment.save!
          special_enrollment
        end

        let(:waiver_subject) { enrollment_builder.build_new_waiver_enrollment(is_qle: true, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
        let(:enrolled_subject) { enrollment_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: true, optional_effective_on: nil) }

        subject(:enrollment) do
          state == "waiver" ? waiver_subject : enrolled_subject
        end

        it "should build a new SEP #{coverage_kind} enrollment with effective date matching QLE on date" do
          expect(enrollment.valid?).to be_truthy
          expect(enrollment.coverage_kind).to eq coverage_kind
          expect(enrollment.effective_on).to eq qle_on
          expect(enrollment.enrollment_kind).to eq 'special_enrollment'
          expect(enrollment.hbx_enrollment_members).to be_present
          expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
          expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
          expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
          expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
        end
      end

      it_behaves_like "under special enrollment period", "health"
      it_behaves_like "under special enrollment period", "dental"
    end
  end

  it_behaves_like "build new enrollment of state", "enrolled"
  it_behaves_like "build new enrollment of state", "waiver"

  shared_examples_for "build_change_enrollment of state" do |state|
    shared_examples_for "when employee making changes for coverage of kind" do |coverage_kind|
      let(:coverage_kind) { coverage_kind }
      context "when employee making changes to dental coverage" do

        let(:build_product_package) { coverage_kind == "health" ? product_package : dental_product_package }

        let!(:previous_enrollment) do
          FactoryBot.create(:hbx_enrollment,
                            household: family.active_household,
                            coverage_kind: coverage_kind,
                            effective_on: enrollment_effective_date,
                            enrollment_kind: "open_enrollment",
                            kind: "employer_sponsored",
                            employee_role_id: person.active_employee_roles.first.id,
                            benefit_group_assignment_id: ce.active_benefit_group_assignment.id,
                            benefit_sponsorship: benefit_sponsorship,
                            sponsored_benefit_package: current_benefit_package,
                            sponsored_benefit: current_benefit_package.sponsored_benefit_for(coverage_kind),
                            product: build_product_package.products[0])
        end

        let(:enrollment_effective_date) { start_on }

        context "during open enrollment period" do

          let(:start_on) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
          let(:open_enrollment_start_on) { TimeKeeper.date_of_record }
          let(:aasm_state) { :enrollment_open }

          let(:waiver_subject) { enrollment_builder.build_change_waiver_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
          let(:enrolled_subject) { enrollment_builder.build_change_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, family_member_ids: family_member_ids) }

          subject(:enrollment) do
            state == "waiver" ? waiver_subject : enrolled_subject
          end

          it "should build an enrollment from previous #{coverage_kind} enrollment" do
            expect(enrollment.valid?).to be_truthy
            expect(enrollment.coverage_kind).to eq coverage_kind
            expect(enrollment.effective_on).to eq previous_enrollment.effective_on
            expect(enrollment.enrollment_kind).to eq 'open_enrollment'
            expect(enrollment.hbx_enrollment_members).to be_present
            expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
            expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
            expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
            expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
          end
        end

        context "during new hire enrollment period" do

          context "with past hired on date" do

            let(:start_on) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
            let(:aasm_state) { :active }

            let!(:ce) do
              census_employee = benefit_sponsorship.census_employees.non_business_owner.first
              census_employee.update(hired_on: TimeKeeper.date_of_record - 2.years)
              census_employee
            end

            let(:waiver_subject) { enrollment_builder.build_change_waiver_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
            let(:enrolled_subject) { enrollment_builder.build_change_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, family_member_ids: family_member_ids) }

            subject(:enrollment) do
              state == "waiver" ? waiver_subject : enrolled_subject
            end

            it "should build an enrollment from previous #{coverage_kind} enrollment" do
              expect(enrollment.valid?).to be_truthy
              expect(enrollment.coverage_kind).to eq coverage_kind
              expect(enrollment.effective_on).to eq previous_enrollment.effective_on
              expect(enrollment.enrollment_kind).to eq 'open_enrollment'
              expect(enrollment.hbx_enrollment_members).to be_present
              expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
              expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
              expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
              expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
            end
          end

          context "with current hired on date" do

            let(:hired_on) { TimeKeeper.date_of_record - 2.days }

            let(:earliest_effective_on) do
              hired_on.mday == 1 ? hired_on : hired_on.next_month.beginning_of_month
            end

            let(:enrollment_effective_date) { earliest_effective_on }

            let!(:ce) do
              census_employee = benefit_sponsorship.census_employees.non_business_owner.first
              census_employee.update(hired_on: hired_on)
              census_employee
            end

            let(:waiver_subject) { enrollment_builder.build_change_waiver_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
            let(:enrolled_subject) { enrollment_builder.build_change_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, family_member_ids: family_member_ids) }

            subject(:enrollment) do
              state == "waiver" ? waiver_subject : enrolled_subject
            end

            it "should build an enrollment from previous #{coverage_kind} enrollment" do
              expect(enrollment.valid?).to be_truthy
              expect(enrollment.coverage_kind).to eq coverage_kind
              expect(enrollment.effective_on).to eq previous_enrollment.effective_on
              expect(enrollment.enrollment_kind).to eq 'open_enrollment'
              expect(enrollment.hbx_enrollment_members).to be_present
              expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
              expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
              expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
              expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
            end
          end

          context "with multiple benefit packages assigned" do

            let(:start_on) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
            let(:aasm_state) { :active }

            let!(:ce) do
              census_employee = benefit_sponsorship.census_employees.non_business_owner.first
              census_employee.update(hired_on: TimeKeeper.date_of_record - 2.years)
              census_employee
            end

            let(:second_product_package) { benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == 'health' && package != product_package } }

            let!(:second_benefit_package) do
              FactoryBot.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: initial_application, product_package: second_product_package)
            end

            let!(:second_benefit_group_assignment) do
              previous_benefit_group_assignment.update_attributes(end_on: previous_benefit_group_assignment.start_on)
              FactoryBot.create(:benefit_group_assignment, benefit_package: second_benefit_package, census_employee: ce, end_on: second_benefit_package.end_on)
            end

            let(:previous_benefit_group_assignment) { ce.benefit_group_assignments.where(benefit_package_id: current_benefit_package).first }

            let(:benefit_package) {ce.benefit_group_assignments.last.benefit_package}
            let(:waiver_subject) { enrollment_builder.build_change_waiver_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
            let(:enrolled_subject) { enrollment_builder.build_change_enrollment(previous_enrollment: previous_enrollment, is_qle: is_qle?, optional_effective_on: nil, family_member_ids: family_member_ids) }

            subject(:enrollment) do
              state == "waiver" ? waiver_subject : enrolled_subject
            end

            it "should have the most recently assigned benefit package from the employer" do
              expect(enrollment.sponsored_benefit_package).to eq benefit_package if coverage_kind == 'health' && state == "enrolled"
            end
          end
        end

        context "during special enrollment period" do

          let(:start_on) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
          let(:aasm_state) { :active }
          let(:qualifying_life_event_kind) { FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date) }
          let(:qle_on) { TimeKeeper.date_of_record - 2.days }

          let!(:special_enrollment_period) do
            special_enrollment = family.special_enrollment_periods.build({
                                                                           qle_on: qle_on,
                                                                           effective_on_kind: "date_of_event"
                                                                         })

            special_enrollment.qualifying_life_event_kind = qualifying_life_event_kind
            special_enrollment.save!
            special_enrollment
          end

          let(:enrollment_effective_date) { qle_on }

          let(:waiver_subject) { enrollment_builder.build_change_waiver_enrollment(previous_enrollment: previous_enrollment, is_qle: true, optional_effective_on: nil, waiver_reason: "this is waiver reason") }
          let(:enrolled_subject) { enrollment_builder.build_change_enrollment(previous_enrollment: previous_enrollment, is_qle: true, optional_effective_on: nil, family_member_ids: family_member_ids) }

          subject(:enrollment) do
            state == "waiver" ? waiver_subject : enrolled_subject
          end

          it "should build an enrollment from previous #{coverage_kind} enrollment" do
            expect(enrollment.valid?).to be_truthy
            expect(enrollment.coverage_kind).to eq coverage_kind
            expect(enrollment.effective_on).to eq previous_enrollment.effective_on
            expect(enrollment.enrollment_kind).to eq 'special_enrollment'
            expect(enrollment.hbx_enrollment_members).to be_present
            expect(enrollment.hbx_enrollment_members.collect(&:applicant_id)).to eq family_member_ids
            expect(enrollment.benefit_sponsorship).to eq benefit_sponsorship
            expect(enrollment.sponsored_benefit_package).to eq current_benefit_package
            expect(enrollment.sponsored_benefit).to eq current_benefit_package.sponsored_benefit_for(coverage_kind)
            expect(enrollment.waiver_reason).to eq "this is waiver reason" if state == "waiver"
          end
        end
      end
    end

    it_behaves_like "when employee making changes for coverage of kind", "health"
    it_behaves_like "when employee making changes for coverage of kind", "dental"
  end

  it_behaves_like "build_change_enrollment of state", "enrolled"
  it_behaves_like "build_change_enrollment of state", "waived"

  describe '#check_for_affected_enrollment' do

    let(:second_product_package) { benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == 'health' && package != product_package } }

    let!(:second_benefit_package) do
      FactoryBot.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: initial_application, product_package: second_product_package)
    end

    let!(:second_benefit_group_assignment) do
      previous_benefit_group_assignment.update_attributes(end_on: previous_benefit_group_assignment.start_on)
      FactoryBot.create(:benefit_group_assignment, benefit_package: second_benefit_package, census_employee: ce, end_on: second_benefit_package.end_on)
    end

    let(:previous_benefit_group_assignment) { ce.benefit_group_assignments.where(benefit_package_id: current_benefit_package).first }

    let(:enrollment_effective_on) { TimeKeeper.date_of_record.beginning_of_month.next_month }
    let(:coverage_kind) { 'health' }

    let!(:existing_enrollment) do
      FactoryBot.create(
        :hbx_enrollment,
        household: family.active_household,
        coverage_kind: coverage_kind,
        effective_on: enrollment_effective_on,
        enrollment_kind: "open_enrollment",
        kind: "employer_sponsored",
        employee_role_id: person.active_employee_roles.first.id,
        benefit_group_assignment_id: previous_benefit_group_assignment.id,
        benefit_sponsorship: benefit_sponsorship,
        sponsored_benefit_package: current_benefit_package,
        sponsored_benefit: current_benefit_package.sponsored_benefit_for(coverage_kind),
        product: product_package.products[0]
      )
    end

    let(:enrolled_subject) { enrollment_builder.build_new_enrollment(family_member_ids: family_member_ids, is_qle: is_qle?, optional_effective_on: effective_on) }

    context "when employee's benefit package is switched" do
      it 'should set predecessor id on the new enrollment' do
        expect(enrolled_subject).to have_attributes(predecessor_enrollment_id: existing_enrollment.id)
      end

      it 'should create enrollment under new benefit package' do
        expect(enrolled_subject.sponsored_benefit_package_id).to eq second_benefit_package.id
      end
    end
  end
end
