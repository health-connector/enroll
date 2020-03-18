# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_site_spec_helpers"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_product_spec_helpers"

RSpec.describe Services::EnrollmentService, type: :model, dbclean: :after_each do
  include_context 'setup benefit market with market catalogs and product packages'
  include_context 'setup initial benefit application'

  context '.process' do
    let(:other_effective_on) {Date.new(TimeKeeper.date_of_record.year, 3, 1)}
    let(:other_plan) {FactoryGirl.create(:benefit_markets_products_health_products_health_product, benefit_market_kind: :aca_shop)}
    let!(:spouse) {FactoryGirl.create(:person)}
    let!(:child1) {FactoryGirl.create(:person)}
    let!(:child2) {FactoryGirl.create(:person)}

    let!(:person) do
      p = FactoryGirl.build(:person)
      p.person_relationships.build(relative: spouse, kind: 'spouse')
      p.person_relationships.build(relative: child1, kind: 'child')
      p.person_relationships.build(relative: child2, kind: 'child')
      p.save
      p
    end

    let(:other_family) do
      family = Family.new({hbx_assigned_id: '24112', e_case_id: '6754632'})
      family.family_members.build(is_primary_applicant: true, person: person)
      family
    end

    let(:hired_on) {TimeKeeper.date_of_record - 2.days}
    let(:household) {other_family.active_household}
    let(:dependent1) do
      other_family.family_members.build(is_primary_applicant: false, person: spouse)
    end

    let(:dependent2) do
      other_family.family_members.build(is_primary_applicant: false, person: child1)
    end

    let(:employee_role1) {FactoryGirl.create(:benefit_sponsors_employee_role, person: person, employer_profile: abc_profile)}
    let(:census_employee) do
      census_employee = FactoryGirl.create(:census_employee, :with_active_assignment, first_name: person.first_name,
                                           last_name: person.last_name, benefit_sponsorship: benefit_sponsorship,
                                           employer_profile: benefit_sponsorship.profile, benefit_group: current_benefit_package,
                                           employee_role_id: employee_role1.id)
      census_employee.update_attributes(ssn: person.ssn, dob: person.dob, hired_on: hired_on)
      census_employee.terminate_employee_role!
      employee_role1.update_attributes(census_employee_id: census_employee.id)
      census_employee
    end

    let(:benefit_group_assignment) {census_employee.active_benefit_group_assignment}
    let(:address) {Address.new(kind: 'home', address_1: '1111 spalding ct', address_2: 'apt 444', city: 'atlanta', state: 'ga', zip: '30338')}
    let(:other_enrollment) do
      other_enrollment = other_family.active_household.hbx_enrollments.build(sponsored_benefit_package_id: benefit_group_assignment.benefit_group.id,
                                                                             hbx_id: '1000006', kind: 'employer_sponsored', product: other_plan, effective_on: other_effective_on,
                                                                             household: household,
                                                                             coverage_kind: 'health',
                                                                             external_enrollment: false,
                                                                             terminated_on: other_effective_on.end_of_month)
      other_enrollment.hbx_enrollment_members.build({applicant_id: other_family.primary_applicant.id, is_subscriber: true, coverage_start_on: other_effective_on, eligibility_date: other_effective_on})
      other_enrollment.hbx_enrollment_members.build({applicant_id: dependent1.id, is_subscriber: false, coverage_start_on: other_effective_on, eligibility_date: other_effective_on})
      other_enrollment.hbx_enrollment_members.build({applicant_id: dependent2.id, is_subscriber: false, coverage_start_on: other_effective_on, eligibility_date: other_effective_on})
      other_enrollment
    end

    let!(:source_family) do
      family = Family.create({hbx_assigned_id: '25112', e_case_id: '6754632'})
      family.family_members.build(is_primary_applicant: true, person: person)
      family.family_members.build(is_primary_applicant: false, person: spouse)
      family.family_members.build(is_primary_applicant: false, person: child1)
      family.family_members.build(is_primary_applicant: false, person: child2)
      family.save
      family
    end

    let(:primary) {source_family.primary_applicant}
    let(:dependent) {source_family.family_members.detect {|fm| !fm.is_primary_applicant}}

    context 'hbx_enrollment' do
      it 'should create new enrollment for terminated employee' do
        enrollment_service = Services::EnrollmentService.new
        enrollment_service.other_enrollment = other_enrollment
        enrollment_service.market = 'shop'
        enrollment_service.process

        source_family.reload
        enrollment = source_family.active_household.hbx_enrollments.where(:hbx_id => other_enrollment.hbx_id).first
        expect(enrollment.present?).to be_truthy
        expect(enrollment.coverage_terminated?).to be_truthy
      end
    end
  end
end