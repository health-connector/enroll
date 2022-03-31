# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe FetchShopBenefit, :dbclean => :after_each do
  context "when shopping in OE" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let!(:ce) { benefit_sponsorship.census_employees.first }
    let!(:ee_person) { FactoryGirl.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
    let!(:employee_role) do
      ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
      ee_person.employee_roles.first
    end

    before :each do
      ce.employee_role_id = ee_person.employee_roles.first.id
      ce.save
      ee_person.employee_roles.first.census_employee_id = ce.id
      ee_person.save
    end

    it "should fetch employee_role" do
      context = described_class.call(employee_role: employee_role, market_kind: "shop")
      expect(context.benefit_group).to be_truthy
    end
  end
end
