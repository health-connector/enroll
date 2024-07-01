# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe BuildEnrollmentForShop, :dbclean => :after_each do
  context "when invalid params are passed" do
    it "should not build hbx_enrollment" do
      context = described_class.call(market_kind: nil)
      expect(context.shopping_enrollments).to eq nil
    end
  end

  context "employer offering only health" do
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
    let!(:primary_family_member)       { family.primary_family_member }
    let!(:coverage_household)       { family.active_household.immediate_family_coverage_household }

    before :each do
      ce.employee_role_id = employee_role.id
      ce.save
      employee_role.census_employee_id = ce.id
      ee_person.save
    end

    context "one member family" do
      context "when health is checked to enroll" do
        it "should build health enrollment" do
          context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll" } } }, coverage_household: coverage_household, employee_role: employee_role)
          expect(context.shopping_enrollments.count).to eq 1
          expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 1
        end
      end
    end

    context "two members family" do
      let!(:dependent) { FactoryBot.create(:person) }
      let!(:family_member) { FactoryBot.create(:family_member, family: family,person: dependent)}
      let!(:coverage_household_member) { coverage_household.coverage_household_members.new(:family_member_id => family_member.id) }

      context "when two members checked to enroll in health" do
        it "should build health enrollment" do
          context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll", family_member.id.to_s => "enroll" } } }, coverage_household: coverage_household,
                                         employee_role: employee_role)
          expect(context.shopping_enrollments.count).to eq 1
          expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 2
        end
      end

      context "when one member is checked to enroll in health" do
        it "should build health enrollment" do
          context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll", family_member.id.to_s => "waive" } } }, coverage_household: coverage_household,
                                         employee_role: employee_role)
          expect(context.shopping_enrollments.count).to eq 1
          expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 1
        end
      end
    end
  end

  context "employer offering health and dental" do
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
    let!(:primary_family_member)       { family.primary_family_member }
    let!(:coverage_household)       { family.active_household.immediate_family_coverage_household }

    before :each do
      ce.employee_role_id = employee_role.id
      ce.save
      employee_role.census_employee_id = ce.id
      ee_person.save
    end

    context "one member family" do
      context "when health is checked to enroll" do
        it "should build health enrollment" do
          # context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll" } } }, coverage_household: coverage_household, employee_role: employee_role)
          # expect(context.shopping_enrollments.count).to eq 1
          # expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 1
        end
      end
    end

    context "two members family" do
      let!(:dependent) { FactoryBot.create(:person) }
      let!(:family_member) { FactoryBot.create(:family_member, family: family,person: dependent)}
      let!(:coverage_household_member) { coverage_household.coverage_household_members.new(:family_member_id => family_member.id) }

      context "when two members checked to enroll in health and dental" do
        it "should build health and dental enrollments" do
          # context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll", family_member.id.to_s => "enroll" } } }, coverage_household: coverage_household,
          #                                employee_role: employee_role)
          # expect(context.shopping_enrollments.count).to eq 1
          # expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 2
        end
      end

      context "when one member is checked to enroll in health and other member is checked to enroll in dental" do
        it "should build health and dental enrollments with respective members" do
          # context = described_class.call(market_kind: "shop", params: {shopping_members: {"health" => { primary_family_member.id.to_s => "enroll", family_member.id.to_s => "waive" } } }, coverage_household: coverage_household,
          #                                employee_role: employee_role)
          # expect(context.shopping_enrollments.count).to eq 1
          # expect(context.shopping_enrollments.first.hbx_enrollment_members.size).to eq 1
        end
      end
    end
  end
end
