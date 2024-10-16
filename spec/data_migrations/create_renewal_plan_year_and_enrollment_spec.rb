# frozen_string_literal: true

require "rails_helper"

require File.join(Rails.root, "app", "data_migrations", "create_renewal_plan_year_and_enrollment")
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe CreateRenewalPlanYearAndEnrollment, dbclean: :after_each do

  let(:given_task_name) { "create_renewal_plan_year_and_passive_renewals" }
  subject { CreateRenewalPlanYearAndEnrollment.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "create_renewal_plan_year_and_passive_renewals", dbclean: :after_each do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let!(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month.prev_year }

    # let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }
    # let(:market_inception) { TimeKeeper.date_of_record.year }
    # let!(:current_effective_date) { Date.new(TimeKeeper.date_of_record.last_year.year, TimeKeeper.date_of_record.month, 1) }
    let(:aasm_state) { :active }
    let!(:benefit_group_assignment) { build(:benefit_group_assignment, start_on: current_benefit_package.start_on, benefit_group_id: nil, benefit_package: current_benefit_package)}
    let(:employee_role) { build(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id)}
    let(:census_employee) do
      create(
        :census_employee,
        dob: TimeKeeper.date_of_record - 21.year,
        employer_profile_id: nil,
        benefit_sponsors_employer_profile_id: abc_profile.id,
        benefit_sponsorship: benefit_sponsorship,
        :benefit_group_assignments => [benefit_group_assignment],
        employee_role_id: employee_role.id
      )
    end
    let(:person) {create(:person,dob: TimeKeeper.date_of_record - 21.year, ssn: census_employee.ssn)}
    let(:family) { create(:family, :with_primary_family_member, person: person)}
    let(:active_household) {family.active_household}
    let(:sponsored_benefit) {current_benefit_package.sponsored_benefits.first}
    let(:reference_product) {sponsored_benefit.reference_product}
    let(:hbx_enrollment_member){ FactoryBot.build(:hbx_enrollment_member, is_subscriber: true, coverage_start_on: current_benefit_package.start_on, eligibility_date: current_benefit_package.start_on, applicant_id: family.family_members.first.id) }
    let(:enrollment) do
      FactoryBot.create(:hbx_enrollment, hbx_enrollment_members: [hbx_enrollment_member],product: reference_product, sponsored_benefit_package_id: current_benefit_package.id, effective_on: initial_application.effective_period.min,
                                         household: family.active_household,benefit_group_assignment_id: benefit_group_assignment.id, employee_role_id: employee_role.id, benefit_sponsorship_id: benefit_sponsorship.id)
    end
    let!(:issuer_profile)  { FactoryBot.create(:benefit_sponsors_organizations_issuer_profile) }
    # let!(:update_reference_product) {reference_product.update_attributes(issuer_profile_id:issuer_profile.id)}

    before(:each) do
      person = family.primary_applicant.person
      person.employee_roles = [employee_role]
      person.employee_roles.map(&:save)
      active_household.hbx_enrollments = [enrollment]
      active_household.save!
    end

    context "when renewal_plan_year" do

      before(:each) do
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:age_bounding).and_return(20)
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate).and_return(15)
      end

      it "should create renewing draft plan year" do
        ClimateControl.modify(
          fein: abc_organization.fein,
          action: "renewal_plan_year"
        ) do
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active]
          subject.migrate
          abc_organization.reload
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active,:draft]
          expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ['coverage_selected']
        end
      end
    end

    context "trigger_renewal_py_for_employers" do

      before(:each) do
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:age_bounding).and_return(20)
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate).and_return(15)
      end

      it "should create renewing plan year" do
        ClimateControl.modify(
          start_on: initial_application.effective_period.min.to_s,
          action: "trigger_renewal_py_for_employers"
        ) do
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active]
          subject.migrate
          abc_organization.reload
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active, :draft]
        end
      end
    end

    context "when renewal_plan_year_passive_renewal" do
      let(:benefit_app) { abc_organization.active_benefit_sponsorship.active_benefit_application }

      before(:each) do
        allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:age_bounding).and_return(20)
        allow(::BenefitMarkets::Products::ProductRateCache).to receive(:lookup_rate).and_return(15)
        ::BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
        ::BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
      end

      it "should create renewing plan year and passive enrollments" do
        ClimateControl.modify(
          fein: abc_organization.fein,
          action: "renewal_plan_year_passive_renewal"
        ) do
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active]
          expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ['coverage_selected']
          subject.migrate
          abc_organization.reload
          family.reload
          expect(abc_organization.employer_profile.benefit_applications.map(&:aasm_state)).to eq [:active, :enrollment_open]
          expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ['coverage_selected','auto_renewing']
        end
      end
    end
  end
end

