# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe Factories::EnrollmentRenewalFactory, dbclean: :around_each do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:renewal_effective_date)          { (TimeKeeper.date_of_record + 45.days).beginning_of_month }
    let(:current_effective_date)          { renewal_effective_date.prev_year }
    let(:product_kinds)                   { [:health, :dental] }
    let(:dental_sponsored_benefit)        { true }
    let(:dental_package_kind)             { :multi_product }
    let(:catalog_health_package_kinds)    { [:single_issuer, :metal_level, :single_product] }
    let(:catalog_dental_package_kinds)    { [:multi_product, :single_issuer] }
    let(:predecessor_application_catalog) { true }
    let!(:renewal_application) do
      application = initial_application.renew
      application.approve_application!
      application.begin_open_enrollment!
      application
    end
    let(:benefit_package) { renewal_application.benefit_packages[0] }
    let(:hired_on)        { TimeKeeper.date_of_record - 2.years }
    let(:person)          { create(:person) }
    let(:shop_family)     { create(:family, :with_primary_family_member, person: person)}
    let(:employee_role)   { create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, hired_on: hired_on, person: person, census_employee: census_employee) }
    let(:enrollment_kind) { "open_enrollment" }
    let(:census_employee) do
      census_employee = create(:census_employee,
             benefit_sponsorship: benefit_sponsorship,
             employer_profile: benefit_sponsorship.profile,
             benefit_group: current_benefit_package,
             hired_on: hired_on)
      census_employee.benefit_group_assignments << build(:benefit_group_assignment, benefit_group: current_benefit_package, census_employee: census_employee, start_on: current_benefit_package.start_on, end_on: current_benefit_package.end_on)
      census_employee.benefit_group_assignments << build(:benefit_group_assignment, benefit_group: benefit_package, census_employee: census_employee, start_on: benefit_package.start_on, end_on: benefit_package.end_on)
      census_employee.save
      census_employee
    end
    let(:sponsored_benefit) { current_benefit_package.sponsored_benefit_for(coverage_kind) }

    let!(:enrollment) do
      FactoryGirl.create(:hbx_enrollment,
                        household: shop_family.latest_household,
                        coverage_kind: coverage_kind,
                        effective_on: current_effective_date,
                        enrollment_kind: 'open_enrollment',
                        kind: "employer_sponsored",
                        submitted_at: current_effective_date - 20.days,
                        benefit_sponsorship_id: benefit_sponsorship.id,
                        sponsored_benefit_package_id: current_benefit_package.id,
                        sponsored_benefit_id: sponsored_benefit.id,
                        employee_role_id: employee_role.id,
                        benefit_group_assignment: census_employee.active_benefit_group_assignment,
                        product_id: sponsored_benefit.reference_product.id,
                        aasm_state: enrollment_status)
    end

    let(:benefit_group_assignment) do
      double("benefit_group_assignment",
             census_employee: census_employee)
    end

    let(:census_employee) { instance_double("census_employee") }
    let(:sponsored_benefit) { instance_double("sponsored_benefit") }

    let(:benefit_package) do
      instance_double("benefit_package",
                      start_on: TimeKeeper.date_of_record)
    end

    context "#product not offered in renewal application" do
      before(:each) do
        allow(census_employee).to receive(:benefit_package_assignment_for).with(benefit_package).and_return(benefit_group_assignment)
        allow(benefit_package).to receive(:sponsored_benefit_for).with(enrollment.coverage_kind).and_return(sponsored_benefit)
        allow(sponsored_benefit).to receive(:products).with(benefit_package.start_on).and_return([product])
      end

      it "should raise error" do
        expect{BenefitSponsors::Factories::EnrollmentRenewalFactory.new(enrollment, benefit_package)}.to raise_error(RuntimeError, "Product not offered in renewal application")
      end
    end

    context 'passive renewals for initial enrollment in waived status' do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:current_effective_date) { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_on) { current_effective_date }
      let(:hired_on) { TimeKeeper.date_of_record - 3.months }
      let(:employee_created_at) { hired_on }
      let(:employee_updated_at) { employee_created_at }
      let(:person) {FactoryGirl.create(:person, first_name: 'John', last_name: 'Smith', dob: '1966-10-10'.to_date, ssn: '123456789')}
      let(:shop_family) {FactoryGirl.create(:family, :with_primary_family_member)}
      let(:aasm_state) { 'inactive' }
      let(:census_employee) { create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package, hired_on: hired_on, created_at: employee_created_at, updated_at: employee_updated_at) }
      let(:employee_role) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person, employer_profile: abc_profile, census_employee_id: census_employee.id, hired_on: census_employee.hired_on) }
      let(:enrollment_kind) { 'open_enrollment' }
      let(:special_enrollment_period_id) { nil }
      let(:waived_enrollment) do
        FactoryGirl.create(:hbx_enrollment,
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
                           special_enrollment_period_id: special_enrollment_period_id,
                           aasm_state: aasm_state
        )
      end

      it 'should create renewal enrollment in waived status when base enrollment is waived' do
        waived_enrollment.benefit_group_assignment = census_employee.active_benefit_group_assignment
        waived_enrollment.save
        enrollment_renewal_factory = BenefitSponsors::Factories::EnrollmentRenewalFactory.new(waived_enrollment, current_benefit_package)
        expect(enrollment_renewal_factory.renewal_enrollment.aasm_state).to eq 'renewing_waived'
      end
    end
  end
end
