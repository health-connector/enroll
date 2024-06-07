# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe SelectMarketKind, :dbclean => :after_each do
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

    subject do
      described_class.call(person: ee_person, params: {})
    end

    it "should fetch market_kind" do
      expect(subject.success?).to be_truthy
      expect(subject.market_kind).to eq "shop"
    end
  end

  context "when a person without employee_role exist" do
    let!(:person) {FactoryBot.create(:person)}

    subject do
      described_class.call(person: person, params: {})
    end

    it "should not fetch market_kind" do
      expect(subject.market_kind).to eq nil
    end
  end

  context "when nil person is passed" do
    subject do
      described_class.call(person: nil, params: {})
    end

    it "should fail with a message" do
      expect(subject.failure?).to be_truthy
      expect(subject.message).to eq "cannot set market kind without person"
    end
  end
end
