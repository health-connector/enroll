# frozen_string_literal: true

require 'rails_helper'

describe BenefitGroupAssignment, type: :model, dbclean: :around_each do
  let(:site)                  { build(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:benefit_sponsor)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:employer_profile)    { benefit_sponsor.employer_profile }
  let(:benefit_sponsorship) do
    sponsorship = employer_profile.add_benefit_sponsorship
    sponsorship.save
    sponsorship
  end
  let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
  let!(:benefit_market_catalog) do
    create(
      :benefit_markets_benefit_market_catalog,
      :with_product_packages,
      benefit_market: site.benefit_markets.first,
      issuer_profile: issuer_profile,
      title: "SHOP Benefits for #{ba_start_on.year}",
      application_period: (ba_start_on.beginning_of_year..ba_start_on.end_of_year)
    )
  end
  let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }
  let!(:service_areas) { benefit_sponsorship.service_areas_on(effective_period.min) }
  let(:ba_start_on)      { TimeKeeper.date_of_record.beginning_of_month.prev_month }
  let(:effective_period) { ba_start_on..ba_start_on.next_year.prev_day }

  let!(:initial_application) do
    create(
      :benefit_sponsors_benefit_application,
      :with_benefit_sponsor_catalog,
      :with_benefit_package,
      benefit_sponsorship: benefit_sponsorship,
      default_effective_period: effective_period,
      aasm_state: :active,
      recorded_rating_area: rating_area,
      recorded_service_areas: service_areas,
      package_kind: :single_product
    )
  end

  let!(:benefit_package) { benefit_sponsorship.benefit_applications.first.benefit_packages.first}
  let(:employee_role_100) { FactoryBot.create(:employee_role, employer_profile: employer_profile) }
  let(:census_employee) do
    ce = FactoryBot.create(:census_employee, employer_profile: employer_profile)
    employee_role_100.update_attributes(census_employee_id: ce.id)
    ce.update_attributes(employee_role_id: employee_role_100.id)
    ce
  end
  let(:start_on)          { benefit_package.start_on }
  let(:hbx_enrollment)  { HbxEnrollment.new(sponsored_benefit_package: benefit_package, employee_role: census_employee.employee_role) }

  describe 'validations' do
    context 'when benefit_group_id is blank' do
      before { subject.benefit_group_id = nil }

      it 'validates presence of benefit_package_id' do
        subject.benefit_package_id = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:benefit_package_id]).to include("can't be blank")
      end
    end

    context 'when benefit_group_id is present' do
      before { subject.benefit_group_id = 1 }

      it 'does not validate presence of benefit_package_id' do
        subject.benefit_package_id = nil
        expect(subject.errors[:benefit_package_id]).to be_empty
      end
    end

    it { should validate_presence_of :start_on }
  end

  describe ".new" do
    let(:valid_params) do
      {
        census_employee: census_employee,
        benefit_package: benefit_package,
        start_on: start_on,
        end_on: benefit_package.end_on,
        hbx_enrollment: hbx_enrollment
      }
    end

    context "with no arguments" do
      let(:params) {{}}

      it "should not save" do
        expect(BenefitGroupAssignment.create(**params).save).to be_falsey
      end
    end

    context "with no start on date" do
      let(:params) {valid_params.except(:start_on)}

      it "should be invalid" do
        expect(BenefitGroupAssignment.create(**params).errors[:start_on].any?).to be_truthy
      end
    end

    context "with no benefit group" do
      let(:params) {valid_params.except(:benefit_package)}

      it "should be invalid" do
        expect(BenefitGroupAssignment.create(**params).errors[:benefit_package_id].any?).to be_truthy
      end
    end

    context "with no census employee" do
      let(:params) {valid_params.except(:census_employee)}

      it "should raise" do
        expect{BenefitGroupAssignment.create(**params)}.to raise_error(Mongoid::Errors::NoParent)
      end
    end

    context "and invalid dates are specified" do
      let(:params) {valid_params}
      let(:benefit_group_assignment)  { BenefitGroupAssignment.new(**params) }

      context "start too early" do
        before { benefit_group_assignment.start_on = benefit_package.plan_year.start_on - 1.day }

        it "should be invalid" do
          expect(benefit_group_assignment.valid?).to be_falsey
          expect(benefit_group_assignment.errors[:start_on].any?).to be_truthy
          expect(benefit_group_assignment.errors.messages[:start_on].first).to match(/can't occur outside plan year dates/)
        end
      end

      context "start too late" do
        before { benefit_group_assignment.start_on = benefit_package.plan_year.end_on + 1.day }

        it "should be invalid" do
          expect(benefit_group_assignment.valid?).to be_falsey
          expect(benefit_group_assignment.errors[:start_on].any?).to be_truthy
          expect(benefit_group_assignment.errors.messages[:start_on].first).to match(/can't occur outside plan year dates/)
        end
      end

      context "end too early" do
        before { benefit_group_assignment.end_on = benefit_package.plan_year.start_on - 1.day }

        it "should be invalid" do
          expect(benefit_group_assignment.valid?).to be_falsey
          expect(benefit_group_assignment.errors[:end_on].any?).to be_truthy
          expect(benefit_group_assignment.errors.messages[:end_on].first).to match(/can't occur outside plan year dates/)
        end
      end

      context "end too late" do
        before { benefit_group_assignment.end_on = benefit_package.plan_year.end_on + 1.day }

        it "should be invalid" do
          expect(benefit_group_assignment.valid?).to be_falsey
          expect(benefit_group_assignment.errors[:end_on].any?).to be_truthy
          expect(benefit_group_assignment.errors.messages[:end_on].first).to match(/can't occur outside plan year dates/)
        end
      end
    end

    context "and valid dates are specified" do
      let(:params) {valid_params}
      let(:benefit_group_assignment)  { BenefitGroupAssignment.new(**params) }

      context "start and end timely" do
        before do
          benefit_group_assignment.start_on = benefit_package.plan_year.start_on
          benefit_group_assignment.end_on   = benefit_package.plan_year.end_on
        end

        it "should be valid" do
          expect(benefit_group_assignment.valid?).to be_truthy
        end
      end
    end

    context "with all valid parameters" do
      let(:params) {valid_params}
      let(:benefit_group_assignment)  { BenefitGroupAssignment.new(**params) }

      it "should save" do
        expect(benefit_group_assignment.save).to be_truthy
      end

      context "and it is saved" do
        let!(:saved_benefit_group_assignment) do
          b = BenefitGroupAssignment.new(**params)
          b.save!
          b
        end

        it "should be findable" do
          expect(BenefitGroupAssignment.find(saved_benefit_group_assignment._id)._id).to eq saved_benefit_group_assignment.id
        end
      end

      context "and benefit coverage activity occurs" do
        context "and coverage is selected" do
          # TODO: Not sure if this can really exist if we depracate aasm_state from here. Previously the hbx_enrollment was checked if coverage_selected?
          # which references the aasm_state, but if thats depracated, not sure hbx_enrollment can be checked any longer.
          # CensusEmployee model has an instance method called create_benefit_package_assignment(new_benefit_package, start_on)
          # which creates a BGA without hbx enrollment.
          # context "without an associated hbx_enrollment" do
          #  let(:params) {valid_params}
          #  let(:invalid_benefit_group_assignment)  { BenefitGroupAssignment.new(**params.except(:hbx_enrollment)) }
          #  it "should be invalid" do
          #    expect(invalid_benefit_group_assignment.valid?).to be_falsey
          #    expect(invalid_benefit_group_assignment.errors[:hbx_enrollment].any?).to be_truthy
          #  end
          # end

          context "with an associated, matching hbx_enrollment" do
            let(:employee_role)   { FactoryBot.build(:employee_role, employer_profile: employer_profile)}
            let(:hbx_enrollment)  { HbxEnrollment.new(sponsored_benefit_package: benefit_package, employee_role: census_employee.employee_role) }

            before { benefit_group_assignment.hbx_enrollment = hbx_enrollment }

            it "should be valid" do
              expect(benefit_group_assignment.valid?).to be_truthy
            end

            context "and hbx_enrollment is non-matching" do

              let(:benefit_sponsor2)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile_initial_application, site: site) }
              let(:benefit_sponsorship2)    { benefit_sponsor2.active_benefit_sponsorship }
              let(:other_employer_profile)      {  benefit_sponsorship2.profile }
              let!(:other_benefit_application) { benefit_sponsorship2.benefit_applications.first}
              let!(:other_benefit_package) { benefit_sponsorship2.benefit_applications.first.benefit_packages.first}
              let(:other_employee_role)     { FactoryBot.create(:employee_role, employer_profile: employer_profile2) }

              context "because it has different benefit group" do
                before do
                  allow(benefit_group_assignment).to receive(:hbx_enrollment).and_return(hbx_enrollment)
                  hbx_enrollment.sponsored_benefit_package = other_benefit_package
                end

                it "should be invalid" do
                  expect(benefit_group_assignment.valid?).to be_falsey
                  expect(benefit_group_assignment.errors[:hbx_enrollment].any?).to be_truthy
                end
              end

              # context "because it has different employee role" do
              #   before { hbx_enrollment.employee_role = other_benefit_group }

              #   it "should be invalid" do
              #     allow(census_employee).to receive(:employee_role_linked?).and_return(true)
              #     expect(benefit_group_assignment.valid?).to be_falsey
              #     expect(benefit_group_assignment.errors[:hbx_enrollment].any?).to be_truthy
              #   end
              # end
            end
          end
        end

        context "and coverage is waived" do
          before { benefit_group_assignment.waive_coverage }

          it "should transistion to coverage waived state" do
            expect(benefit_group_assignment.coverage_waived?).to be_truthy
          end

          context "and waived coverage is terminated" do

            it "should fail transition and remain in coverage waived state" do
              expect { benefit_group_assignment.terminate_coverage! }.to raise_error AASM::InvalidTransition
              expect(benefit_group_assignment.coverage_waived?).to be_truthy
            end
          end

          context "and the employee reconsiders and selects coverage" do
            before { benefit_group_assignment.select_coverage }

            it "should transistion back to coverage selcted state" do
              expect(benefit_group_assignment.coverage_selected?).to be_truthy
            end

            context "and coverage is terminated" do
              before { benefit_group_assignment.terminate_coverage }

              it "should transistion to coverage terminated state" do
                expect(benefit_group_assignment.coverage_terminated?).to be_truthy
              end
            end
          end
        end

        context "and coverage is terminated" do
          let(:household) { create(:household, family: family)}
          let(:family) { create(:family, :with_primary_family_member)}
          # let(:employee_role)   { FactoryBot.build(:employee_role, employer_profile: employer_profile, census_employee_id: census_employee.id)}
          let(:hbx_enrollment1) do
            FactoryBot.create(
              :hbx_enrollment,
              employee_role: census_employee.employee_role,
              household: household,
              aasm_state: 'coverage_selected',
              benefit_group_assignment_id: benefit_group_assignment.id,
              sponsored_benefit_package_id: benefit_package.id,
              effective_on: TimeKeeper.date_of_record.prev_month
            )
          end

          it "should update the end_on date to terminated date only if CE is termed/pending" do
            census_employee.update_attributes!(aasm_state: 'employee_termination_pending', coverage_terminated_on: TimeKeeper.date_of_record - 2.days)
            hbx_enrollment1.benefit_group_assignment = benefit_group_assignment
            benefit_group_assignment.hbx_enrollment = hbx_enrollment1
            benefit_group_assignment.save
            hbx_enrollment1.save
            hbx_enrollment1.term_or_cancel_enrollment(hbx_enrollment1, TimeKeeper.date_of_record - 2.days)
            expect(benefit_group_assignment.end_on).to eq(TimeKeeper.date_of_record - 2.days)
          end

          it "should NOT update the end_on date to terminated date when CE is active" do
            hbx_enrollment1.benefit_group_assignment = benefit_group_assignment
            benefit_group_assignment.hbx_enrollment = hbx_enrollment1
            benefit_group_assignment.save
            hbx_enrollment1.term_or_cancel_enrollment(hbx_enrollment1, TimeKeeper.date_of_record + 2.days)
            expect(benefit_group_assignment.end_on).not_to eq(TimeKeeper.date_of_record + 2.days)
          end
        end

        context "and benefit group is disabled" do
          before do
            census_employee.benefit_group_assignments << benefit_group_assignment
            benefit_sponsorship.census_employees << census_employee
            benefit_package.cancel_member_benefits
          end

          it "should update the benefit application group end on date" do
            expect(benefit_group_assignment.end_on).to eq(benefit_group_assignment.start_on)
          end
        end

      end
    end
  end

  describe '#hbx_enrollments', dbclean: :after_each do

    let!(:census_employee) do
      ce = create :census_employee, employer_profile: employer_profile, employee_role_id: employee_role.id
      employee_role.update_attributes(census_employee_id: ce.id)
      ce
    end
    let!(:employee_role) { create(:employee_role, person: person, employer_profile: employer_profile)}
    let(:person) { family.primary_person }
    let!(:household) { create(:household, family: family)}
    let(:family) { create(:family, :with_primary_family_member)}
    let!(:benefit_group_assignment) { create(:benefit_group_assignment, end_on: benefit_package.end_on, benefit_package: benefit_package, census_employee: census_employee) }

    shared_examples_for "active, waived and terminated enrollments" do |state, status, result, match_with_package_id, match_with_assignment_id|

      let!(:enrollment) do
        FactoryBot.create(
          :hbx_enrollment, household: household,
                           :benefit_group_assignment_id => match_with_assignment_id ? census_employee.active_benefit_group_assignment.id : nil,
                           :sponsored_benefit_package_id => match_with_package_id ? census_employee.active_benefit_group_assignment.benefit_package_id : nil,
                           :employee_role_id => employee_role.id,
                           :aasm_state => state
        )
      end

      it "should #{status}return the #{state} enrollments" do
        result = [enrollment] if result == "enrollment"
        expect(census_employee.active_benefit_group_assignment.hbx_enrollments).to eq result
      end
    end

    it_behaves_like "active, waived and terminated enrollments", "coverage_canceled", "not", [], true, true
    it_behaves_like "active, waived and terminated enrollments", "coverage_terminated", "", "enrollment", true, true
    it_behaves_like "active, waived and terminated enrollments", "coverage_expired", "", "enrollment", true, false
    it_behaves_like "active, waived and terminated enrollments", "coverage_selected", "", "enrollment", false, true
    it_behaves_like "active, waived and terminated enrollments", "inactive", "", "enrollment", false, true
    it_behaves_like "active, waived and terminated enrollments", "inactive", "", [], false, false
    it_behaves_like "active, waived and terminated enrollments", "coverage_selected", "", [], false, false
  end

  describe '#active_and_waived_enrollments', dbclean: :after_each do

    let(:household) { create(:household, family: family)}
    let(:family) { create(:family, :with_primary_family_member)}
    let(:hbx_enrollment) { create(:hbx_enrollment, household: household, aasm_state: 'renewing_waived', sponsored_benefit_package_id: benefit_package.id) }
    let!(:benefit_group_assignment) { create(:benefit_group_assignment, benefit_package: benefit_package, census_employee: census_employee, hbx_enrollment: hbx_enrollment)}

    shared_examples_for "active and waived enrollments" do |state, status, result|

      let!(:enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: household,
          benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
          aasm_state: state
        )
      end

      it "should #{status}return the #{state} enrollments" do
        result = [enrollment] if result == "active_enrollment"
        expect(census_employee.active_benefit_group_assignment.active_and_waived_enrollments).to eq result
      end
    end

    it_behaves_like "active and waived enrollments", "coverage_terminated", "not ", []
    it_behaves_like "active and waived enrollments", "coverage_expired", "not ", []
    it_behaves_like "active and waived enrollments", "coverage_selected", "", "active_enrollment"
    it_behaves_like "active and waived enrollments", "inactive", "", "active_enrollment"
  end

  describe '#active_enrollments', dbclean: :after_each do

    let(:household) { FactoryBot.create(:household, family: family)}
    let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: household, aasm_state: 'coverage_selected', sponsored_benefit_package_id: benefit_package.id) }
    let!(:benefit_group_assignment) { FactoryBot.create(:benefit_group_assignment, benefit_package: benefit_package, census_employee: census_employee, hbx_enrollment: hbx_enrollment)}
    let!(:employee_role) do
      ee = FactoryBot.create(:employee_role, person: family.primary_person, employer_profile: employer_profile, census_employee: census_employee)
      census_employee.update_attributes!(employee_role_id: ee.id)
      ee
    end

    let(:census_employee2)   { FactoryBot.create(:census_employee, employer_profile: employer_profile) }
    let!(:employee_role2) do
      ee = FactoryBot.create(:employee_role, person: family2.primary_person, employer_profile: employer_profile, census_employee: census_employee2)
      census_employee2.update_attributes!(employee_role_id: ee.id)
      ee
    end
    let(:household2) { FactoryBot.create(:household, family: family2)}
    let(:family2) { FactoryBot.create(:family, :with_primary_family_member)}
    let!(:benefit_group_assignment2) { FactoryBot.create(:benefit_group_assignment, benefit_package: benefit_package, census_employee: census_employee2, end_on: benefit_package.end_on)}
    let!(:enrollment_family2) do
      FactoryBot.create(
        :hbx_enrollment,
        household: household2,
        benefit_group_assignment_id: census_employee2.active_benefit_group_assignment.id,
        sponsored_benefit_package_id: census_employee2.active_benefit_group_assignment.benefit_package_id,
        employee_role_id: employee_role2.id,
        aasm_state: 'coverage_selected'
      )
    end

    shared_examples_for "active enrollments" do |state, status, result, match_with_package_id, match_with_assignment_id|
      let!(:enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: household,
          employee_role_id: employee_role.id,
          benefit_group_assignment_id: match_with_assignment_id ? census_employee.active_benefit_group_assignment.id : nil,
          sponsored_benefit_package_id: match_with_package_id ? census_employee.active_benefit_group_assignment.benefit_package_id : nil,
          aasm_state: state
        )
      end

      it "#covered_families" do
        expect(census_employee.active_benefit_group_assignment.covered_families.count).to eq 1
      end

      it "should #{status}return the #{state} enrollments" do
        result = [enrollment] if result == "active_enrollment"
        expect(census_employee.active_benefit_group_assignment.active_enrollments).to eq result
      end
    end

    it_behaves_like "active enrollments", "coverage_terminated", "not ", [], true, true
    it_behaves_like "active enrollments", "coverage_expired", "not ", [], false, true
    it_behaves_like "active enrollments", "coverage_selected", "", "active_enrollment", false, true
    it_behaves_like "active enrollments", "inactive", "not", [], true, true
    it_behaves_like "active enrollments", "coverage_selected", "", [], false, false
  end

  describe '#covered_families_with_benefit_assignemnt', dbclean: :after_each do

    let!(:household) { FactoryBot.create(:household, family: family)}
    let(:family) { FactoryBot.create(:family, :with_primary_family_member)}
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: household, aasm_state: 'coverage_selected', benefit_group_assignment_id: benefit_group_assignment.id, employee_role_id: employee_role.id) }
    let!(:benefit_group_assignment) { FactoryBot.create(:benefit_group_assignment, census_employee: census_employee)}
    let!(:employee_role) do
      ee = FactoryBot.create(:employee_role, person: family.primary_person, employer_profile: employer_profile, census_employee: census_employee)
      census_employee.update_attributes!(employee_role_id: ee.id)
      ee
    end

    before do
      family.active_household.hbx_enrollments = [hbx_enrollment]
      family.save!
      allow(census_employee).to receive(:active_benefit_group_assignment).and_return(benefit_group_assignment)
    end

    it "should return the covered families" do
      expect(census_employee.active_benefit_group_assignment.covered_families_with_benefit_assignemnt.count).to eq 1
      expect(census_employee.active_benefit_group_assignment.covered_families_with_benefit_assignemnt.first).to eq family
    end
  end

  describe '.make_active' do
    let!(:census_employee) do
      FactoryBot.create(
        :census_employee,
        :with_active_assignment,
        benefit_sponsorship: benefit_sponsorship,
        employer_profile: employer_profile,
        employee_role_id: employee_role_100.id,
        benefit_group: benefit_package
      )
    end

    context "and benefit coverage activity occurs" do
      it "should update the benfefit group assignment" do
        expect(census_employee.benefit_group_assignments.first.make_active).to be_truthy
      end

      it "should not update end_on date for inactive BGA" do
        census_employee.benefit_group_assignments.first.update_attributes!(end_on: nil)
        allow(census_employee.benefit_group_assignments.first).to receive(:is_active?).and_return(false)
        census_employee.benefit_group_assignments.first.make_active
        census_employee.benefit_group_assignments.first.reload
        expect(census_employee.benefit_group_assignments.first.end_on).to eq(nil)
      end
    end
  end

  # describe '.cover_date' do

  #   before do
  #     census_employee.benefit_group_assignments = []
  #   end

  #   context 'for offcyle renewal' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2017,5,1), end_on: nil) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: Date.new(2019,3,31)) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,4,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2020, 10, 30))).to be_empty
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 10, 30))).to eq [assignment_three]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 6, 30))).to eq [assignment_two]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 5, 30))).to eq [assignment_one]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 1, 30))).to be_empty
  #     end
  #   end

  #   context 'for gapped coverage' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2017,5,1), end_on: nil) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: Date.new(2019,3,31)) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2020, 10, 30))).to be_empty
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 10, 30))).to eq [assignment_three]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 6, 30))).to eq [assignment_two]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 5, 30))).to eq [assignment_one]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 1, 30))).to be_empty
  #     end
  #   end

  #   context 'for renewal' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2017,5,1), end_on: nil) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: nil) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2020, 10, 30))).to be_empty
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 10, 30))).to eq [assignment_three]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 10, 30))).to eq [assignment_two]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 10, 30))).to eq [assignment_one]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 1, 30))).to be_empty
  #     end
  #   end

  #   context 'for renewal cancel draft' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2017,5,1), end_on: nil) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: Date.new(2019,3,31)) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: Date.new(2019,5,1)) }
  #     let!(:assignment_four)  { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2020, 10, 30))).to be_empty
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 5, 1))).to eq [assignment_three, assignment_four]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 6, 30))).to eq [assignment_two]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 5, 30))).to eq [assignment_one]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 1, 30))).to be_empty
  #     end
  #   end

  #   context 'for cancel draft' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: Date.new(2018,5,1)) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: nil) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2020, 10, 30))).to be_empty
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 10, 30))).to eq [assignment_three]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 5, 1))).to eq [assignment_one, assignment_two]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2017, 5, 30))).to be_empty
  #     end
  #   end

  #   context 'for multiple assignments' do
  #     let!(:assignment_one)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: nil) }
  #     let!(:assignment_two)   { census_employee.benefit_group_assignments.build(start_on: Date.new(2018,8,1), end_on: nil) }
  #     let!(:assignment_three) { census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil) }

  #     it 'should pull benefit group assignment' do
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2019, 10, 30))).to eq [assignment_three]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 5, 20))).to eq  [assignment_one]
  #       expect(census_employee.benefit_group_assignments.cover_date(Date.new(2018, 10, 10))).to eq [assignment_two, assignment_one]
  #     end
  #   end
  # end

  describe '.on_date' do

    before do
      census_employee.benefit_group_assignments = []
    end

    context 'for multiple assignments' do
      let!(:assignment_one) do
        bga = census_employee.benefit_group_assignments.build(start_on: Date.new(2018,5,1), end_on: nil, benefit_package_id: benefit_package.id)
        bga.save(validate: false)
        bga
      end
      let!(:assignment_two) do
        bga = census_employee.benefit_group_assignments.build(start_on: Date.new(2018,8,1), end_on: nil, benefit_package_id: benefit_package.id)
        bga.save(validate: false)
        bga
      end
      let!(:assignment_three) do
        bga = census_employee.benefit_group_assignments.build(start_on: Date.new(2019,5,1), end_on: nil, benefit_package_id: benefit_package.id)
        bga.save(validate: false)
        bga
      end

      it 'should pull benefit group assignment with later begin date' do
        expect(BenefitGroupAssignment.on_date(census_employee, Date.new(2019, 10, 30))).to eq assignment_three
        expect(BenefitGroupAssignment.on_date(census_employee, Date.new(2018, 5, 20))).to  eq assignment_one
        expect(BenefitGroupAssignment.on_date(census_employee, Date.new(2018, 10, 10))).to eq assignment_two
      end

      context 'when start_on is nil' do
        let!(:assignment_four) do
          bga = census_employee.benefit_group_assignments.build(start_on: nil, end_on: nil, benefit_package_id: benefit_package.id)
          bga.save(validate: false)
          bga
        end

        it 'should not raise error and return bga' do
          expect(BenefitGroupAssignment.on_date(census_employee, Date.new(2019, 10, 30))).to eq assignment_three
        end
      end

      context 'when two bgas with end_on nil' do

        before do
          assignment_one.start_on = TimeKeeper.date_of_record.beginning_of_month
          assignment_one.save(validate: false)
          assignment_two.start_on = TimeKeeper.date_of_record.beginning_of_month.prev_month
          assignment_two.save(validate: false)
        end

        it 'should return bga with max start_on' do
          expect(BenefitGroupAssignment.on_date(census_employee, TimeKeeper.date_of_record)).to eq assignment_one
        end
      end
    end
  end
end
