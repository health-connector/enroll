require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  describe PlanSelection, dbclean: :after_each do

    subject { PlanSelection.new(hbx_enrollment, hbx_enrollment.plan) }

    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    let(:person1) { FactoryGirl.create(:person, :with_consumer_role) }

    let(:family) {FactoryGirl.create(:family, :with_primary_family_member, :person => person)}
    let(:household) {FactoryGirl.create(:household, family: family)}

    let(:year){ TimeKeeper.date_of_record.year }
    let(:effective_on) { Date.new(year, 3, 1)}
    let(:previous_enrollment_status) { 'coverage_selected' }
    let(:terminated_on) { nil }
    let(:covered_individuals) { family.family_members }
    let(:newly_covered_individuals) { family.family_members }

    let(:plan) {
      FactoryGirl.create(:plan, :with_premium_tables, market: 'individual', metal_level: 'silver', active_year: year, hios_id: "11111111122301-01", csr_variant_id: "01")
    }

    let!(:previous_coverage){
      FactoryGirl.create(:hbx_enrollment,:with_enrollment_members,
       enrollment_members: covered_individuals,
       household: family.latest_household,
       coverage_kind: "health",
       effective_on: effective_on.beginning_of_year,
       enrollment_kind: "open_enrollment",
       kind: "individual",
       consumer_role: person.consumer_role,
       plan: plan,
       aasm_state: previous_enrollment_status,
       terminated_on: terminated_on
       ) }

    let!(:hbx_enrollment) {
      FactoryGirl.create(:hbx_enrollment,:with_enrollment_members,
       enrollment_members: newly_covered_individuals,
       household: family.latest_household,
       coverage_kind: "health",
       effective_on: effective_on,
       enrollment_kind: "open_enrollment",
       kind: "individual",
       consumer_role: person.consumer_role,
       plan: plan
       )
    }

    before do
      TimeKeeper.set_date_of_record_unprotected!(effective_on)
    end

    describe '.existing_enrollment_for_covered_individuals' do

      context 'when active coverage present' do
        it 'should return active coverage' do
          expect(subject.existing_enrollment_for_covered_individuals).to eq previous_coverage
        end
      end

      context 'when previous coverage is terminated' do
        context 'and there is a gap in coverage' do
         let(:previous_enrollment_status) { 'coverage_terminated' }
         let(:terminated_on) { effective_on - 10.days }

          it 'should not return terminated enrollment' do
            expect(subject.existing_enrollment_for_covered_individuals).to be_nil
          end
        end

        context 'and no gap in coverage' do
          let(:previous_enrollment_status) { 'coverage_terminated' }
          let(:terminated_on) { effective_on.prev_day }

          it 'should return terminated enrollment' do
            expect(subject.existing_enrollment_for_covered_individuals).to eq previous_coverage
          end
        end
      end

      context 'when member not coverged before' do
        let(:family_member) { FactoryGirl.create(:family_member, family: family, person: person1)}
        let(:covered_individuals) { family.family_members.select{|fm| fm != family_member} }
        let(:newly_covered_individuals) { family_member.to_a }

        it 'should return nothing' do
          expect(subject.existing_enrollment_for_covered_individuals).to be_nil
        end
      end
    end

    describe '.set_enrollment_member_coverage_start_dates' do
      context 'when a new enrollment has a previous enrollment' do
        def hash_key_creator(hbx_enrollment_member)
          hbx_enrollment_member.person.hbx_id
        end
        it 'should set eligibility dates to that of the previous enrollment' do
          subject.set_enrollment_member_coverage_start_dates
          previous_eligibility_dates = Hash[previous_coverage.hbx_enrollment_members.collect {|hbx_em| [hash_key_creator(hbx_em), hbx_em.coverage_start_on]} ]
          new_eligibility_dates = Hash[hbx_enrollment.hbx_enrollment_members.collect {|hbx_em| [hash_key_creator(hbx_em), hbx_em.coverage_start_on]} ]
          new_eligibility_dates.each do |hbx_id,date|
            expect(previous_eligibility_dates[hbx_id]).to eq(date)
          end
        end
      end
    end

    describe ".select_plan_and_deactivate_other_enrollments" do

      context 'hbx_enrollment aasm state check' do
        it 'should set eligibility dates to that of the previous enrollment' do
          subject.hbx_enrollment.hbx_enrollment_members.flat_map(&:person).flat_map(&:consumer_role).first.update_attribute("aasm_state","verification_outstanding")
          subject.select_plan_and_deactivate_other_enrollments(nil,"individual")
          expect(subject.hbx_enrollment.aasm_state).to eq("enrolled_contingent")
        end
      end
    end
  end
end

describe PlanSelection, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup renewal application"


  let(:current_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month - 1.year }
  let(:effective_on) { current_effective_date }
  let(:hired_on) { TimeKeeper.date_of_record - 3.months }

  let(:person) {FactoryGirl.create(:person)}
  let(:shop_family) {FactoryGirl.create(:family, :with_primary_family_member, person: person)}

  let(:aasm_state) { :active }
  let(:census_employee) do
    create(:census_employee,
           :with_active_assignment,
           benefit_sponsorship: benefit_sponsorship,
           employer_profile: benefit_sponsorship.profile,
           expected_selection: "waive",
           benefit_group: current_benefit_package,
           hired_on: hired_on,
           employee_role_id: employee_role.id)
  end
  let(:employee_role) { FactoryGirl.create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: hired_on, person: person) }
  let(:enrollment_kind) { "open_enrollment" }
  let(:special_enrollment_period_id) { nil }

  let!(:initial_enrollment) do
    enrollment = shop_family.latest_household.hbx_enrollments.create!(coverage_kind: "health",
                                                                      effective_on: renewal_effective_date - 2.months,
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
                                                                      aasm_state: "shopping")

    enrollment.waive_coverage!
    renewal_application.update_attributes(aasm_state: :enrollment_open)
    enrollment
  end

  let!(:renewal_enrollment) do
    enrollment = shop_family.latest_household.hbx_enrollments.create!(coverage_kind: "health",
                                                                      effective_on: renewal_effective_date,
                                                                      enrollment_kind: enrollment_kind,
                                                                      kind: "employer_sponsored",
                                                                      submitted_at: renewal_effective_date - 1.month,
                                                                      benefit_sponsorship_id: benefit_sponsorship.id,
                                                                      sponsored_benefit_package_id: benefit_package.id,
                                                                      sponsored_benefit_id: benefit_package.sponsored_benefits[0].id,
                                                                      employee_role_id: employee_role.id,
                                                                      benefit_group_assignment_id: census_employee.renewal_benefit_group_assignment.id,
                                                                      special_enrollment_period_id: special_enrollment_period_id,
                                                                      product_id: benefit_package.sponsored_benefits[0].reference_product.id,
                                                                      aasm_state: "shopping")
    enrollment.renew_waived!
    enrollment
  end

  let!(:sep_enrollment) do
    shop_family.latest_household.hbx_enrollments.create!(coverage_kind: "health",
                                                         effective_on: effective_on + 11.months,
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
                                                         aasm_state: "shopping",
                                                         predecessor_enrollment_id: initial_enrollment.id)
  end

  subject { described_class.new(sep_enrollment, initial_enrollment.product) }

  before do
    allow_any_instance_of(BenefitMarkets::Products::HealthProducts::HealthProduct).to receive(:renewal_product).and_return(product_package.products.last)
  end

  after do
    TimeKeeper.set_date_of_record_unprotected!(Date.today)
  end

  describe ".select_plan_and_deactivate_other_enrollments" do
    context 'hbx_enrollment aasm state check' do
      it 'should generate renewal enrollment' do
        census_employee.employee_role_id = employee_role.id
        census_employee.save
        employee_role.census_employee_id = census_employee.id
        person.save
        subject.select_plan_and_deactivate_other_enrollments(initial_enrollment.id,nil)
        expect(shop_family.active_household.hbx_enrollments.last.aasm_state).to eq("auto_renewing")
      end
    end
  end
end
