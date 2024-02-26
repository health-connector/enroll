# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe FetchShoppingProducts, :dbclean => :after_each do
  # product shopping is done and nothing to shop for
  context "when it is continuous show and shop for is nil" do
    it "should not fetch products" do
      context = described_class.call(action: "continuous_show", shop_for: nil)
      expect(context.products).to eq nil
    end
  end

  # product shopping is not done and shopping for health/dental
  context "when it is not continuous show and shop for is not nil" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let!(:ce) { benefit_sponsorship.census_employees.first }
    let!(:ee_person) { FactoryBot.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
    let!(:employee_role) do
      ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
      ee_person.employee_roles.first
    end
    let!(:family)       { ee_person.primary_family }
    let!(:hbx_enrollment) do
      hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members,
                                          household: family.active_household,
                                          aasm_state: "shopping",
                                          effective_on: initial_application.start_on,
                                          rating_area_id: initial_application.recorded_rating_area_id,
                                          sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                          sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                          benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                          employee_role_id: employee_role.id)
      hbx_enrollment.benefit_sponsorship = benefit_sponsorship
      hbx_enrollment.save!
      hbx_enrollment
    end

    before :each do
      ce.employee_role_id = ee_person.employee_roles.first.id
      ce.save
      ee_person.employee_roles.first.census_employee_id = ce.id
      ee_person.save
    end

    it "should fetch products" do
      context = described_class.call(action: "continuous_show", shop_for: "health", hbx_enrollment: hbx_enrollment, coverage_kind: "health", enrolled_hbx_enrollment_plan_ids: [])
      expect(context.products.present?).to be_truthy
    end
  end
end
