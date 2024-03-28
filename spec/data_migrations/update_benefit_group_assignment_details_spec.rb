# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "change_enrollment_details")

describe ChangeEnrollmentDetails do

  let(:given_task_name) { "update_benefit_group_assignment_details" }
  subject { UpdateBenefitGroupAssignmentDetails.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing enrollment attributes" do

    let(:start_date) { TimeKeeper.date_of_record}
    let(:end_date) { TimeKeeper.date_of_record - 5.days}
    let(:current_effective_date)  { TimeKeeper.date_of_record }
    let(:start_on)  { current_effective_date.prev_month }
    let(:effective_period)  { start_on..start_on.next_year.prev_day }
    let!(:site) { create(:benefit_sponsors_site,:with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, :cca) }
    let!(:org) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:employer_profile) { org.employer_profile }
    let!(:rating_area) { FactoryBot.create_default :benefit_markets_locations_rating_area }
    let!(:service_area) { FactoryBot.create_default :benefit_markets_locations_service_area }
    let(:benefit_sponsorship) do
      sponsorship = employer_profile.add_benefit_sponsorship
      sponsorship.save
      sponsorship
    end
    let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
    let(:benefit_market) { site.benefit_markets.first }
    let(:benefit_market_catalog) { benefit_market.benefit_market_catalogs.first }
    let!(:product_package) { benefit_market_catalog.product_packages.where(package_kind: :single_issuer).first }
    let!(:benefit_package) { FactoryBot.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: benefit_application, product_package: product_package) }
    let!(:benefit_application) { FactoryBot.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :active) }
    let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, sponsored_benefit_package_id: benefit_package.id, household: family.active_household)}
    let!(:benefit_group_assignment) do
      FactoryBot.create(:benefit_group_assignment, census_employee: census_employee,  benefit_package: benefit_package, hbx_enrollment: hbx_enrollment, start_on: benefit_application.start_on, aasm_state: "coverage_selected")
    end
    let(:census_employee) { FactoryBot.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship) }

    before(:each) do
      benefit_application.benefit_application_items.create(
        effective_period: effective_period,
        sequence_id: 1,
        state: benefit_application.aasm_state
      )
      allow(ENV).to receive(:[]).with("ce_id").and_return(census_employee.id.to_s)
      allow(ENV).to receive(:[]).with("bga_id").and_return(benefit_group_assignment.id)
      allow(ENV).to receive(:[]).with("new_state").and_return "coverage_void"
      allow(ENV).to receive(:[]).with("action").and_return "change_aasm_state"
    end

    it "should change the aasm state" do
      ClimateControl.modify(
        ce_id: census_employee.id.to_s,
        bga_id: benefit_group_assignment.id,
        new_state: 'coverage_void',
        action: "change_aasm_state"
      ) do
        subject.migrate
        benefit_group_assignment.reload
        expect(benefit_group_assignment.aasm_state).to eq "coverage_void"
      end
    end
  end
end
