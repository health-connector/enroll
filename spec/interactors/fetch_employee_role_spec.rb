# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe FetchEmployeeRole, :dbclean => :after_each do
  context "when a person with employee_role exist" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let!(:ce) { benefit_sponsorship.census_employees.first }
    let!(:ee_person) { FactoryBot.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
    let!(:employee_role) do
      ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
      ee_person.employee_roles.first
    end
    let!(:employee_role_id) { employee_role.id.to_s}

    before :each do
      ce.employee_role_id = ee_person.employee_roles.first.id
      ce.save
      ee_person.employee_roles.first.census_employee_id = ce.id
      ee_person.save
    end

    it "should fetch employee_role" do
      context = described_class.call(params: {employee_role_id: employee_role_id}, person: ee_person)
      expect(context.employee_role.present?).to be_truthy
      expect(context.census_employee.id).to eq ce.id
    end
  end

  context "when a person without employee_role exist" do
    let!(:person) {FactoryBot.create(:person)}

    subject do
      described_class.call(params: {employee_role_id: "1234"}, person: person)
    end

    it "return's nil employee_role" do
      expect(subject.employee_role).to eq nil
    end

    it "should fail with a message" do
      expect(subject.failure?).to be_truthy
      expect(subject.message).to eq "invalid employee role ID"
    end
  end

  context "with nil employee_role_id" do
    let!(:person) {FactoryBot.create(:person)}

    subject do
      described_class.call(params: {employee_role_id: nil}, person: person)
    end

    it "should fail with a message" do
      expect(subject.failure?).to be_truthy
      expect(subject.message).to eq "missing employee_role_id  in params"
    end
  end
end
