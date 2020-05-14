require"rails_helper"
require File.join(Rails.root, "app", "data_migrations", "golden_seed")

describe GoldenSeed, dbclean: :after_each do
  let(:benefit_application) { BenefitApplications::BenefitApplication.new }

  # let(:date_range) { (Date.today..1.year.from_now) }

  let(:effective_period_start_on) { TimeKeeper.date_of_record.end_of_month + 1.day + 1.month }
  let(:effective_period_end_on)   { effective_period_start_on + 1.year - 1.day }
  let(:effective_period)          { effective_period_start_on..effective_period_end_on }

  let(:open_enrollment_period_start_on) { effective_period_start_on.prev_month }
  let(:open_enrollment_period_end_on)   { open_enrollment_period_start_on + 9.days }
  let(:open_enrollment_period)          { open_enrollment_period_start_on..open_enrollment_period_end_on }

  let(:params) do
    {
      effective_period: effective_period,
      open_enrollment_period: open_enrollment_period,
    }
  end

  let(:benefit_application)       { SponsoredBenefits::BenefitApplications::BenefitApplication.new(params) }
  let(:benefit_sponsorship)       { SponsoredBenefits::BenefitSponsorships::BenefitSponsorship.new(
    benefit_market: "aca_shop_cca",
    enrollment_frequency: "rolling_month"
  )}

  let(:address)  { Address.new(kind: "primary", address_1: "609 H St", city: "Boston", state: "MA", zip: "02109", county: "Suffolk") }
  let(:phone  )  { Phone.new(kind: "main", area_code: "202", number: "555-9999") }
  let(:office_location) { OfficeLocation.new(
      is_primary: true,
      address: address,
      phone: phone
    )
  }
  let(:benefit_group)             { FactoryGirl.create :benefit_group, title: 'new' }

  let(:benefit_market)      { site.benefit_markets.first }
  let(:current_effective_date)  { TimeKeeper.date_of_record }
  let!(:benefit_market_catalog) { create(:benefit_markets_benefit_market_catalog, :with_product_packages,
                                         benefit_market: benefit_market,
                                         title: "SHOP Benefits for #{current_effective_date.year}",
                                         application_period: (effective_period_start_on.beginning_of_year..effective_period_start_on.end_of_year))

  }
  let!(:product)      { benefit_market_catalog.product_packages.where(package_kind: 'single_product').first.products.first}
  let!(:plan) {benefit_group.reference_plan}
  let!(:rating_area)   { FactoryGirl.create_default :benefit_markets_locations_rating_area, active_year: effective_period_start_on.year }
  let!(:service_area)  { FactoryGirl.create_default :benefit_markets_locations_service_area, active_year: effective_period_start_on.year }
  let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:benefit_sponsor_organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site, legal_name: 'Broadcasting llc') }
  let(:sponsor_benefit_sponsorship) { benefit_sponsor_organization.employer_profile.add_benefit_sponsorship }

  let(:plan_design_organization)  { SponsoredBenefits::Organizations::PlanDesignOrganization.new(legal_name: "plan design xyz", office_locations: [office_location], sic_code: sic_code) }
  let(:plan_design_proposal)      { SponsoredBenefits::Organizations::PlanDesignProposal.new(title: "New Proposal") }
  let(:sic_code) { "123345" }
  let(:profile) {SponsoredBenefits::Organizations::AcaShopCcaEmployerProfile.new(sic_code: sic_code) }

  before(:each) do
    plan.hios_id = product.hios_id
    plan.save
    sponsor_benefit_sponsorship.rating_area = rating_area
    sponsor_benefit_sponsorship.service_areas = [service_area]
    sponsor_benefit_sponsorship.save
    plan_design_organization.plan_design_proposals << [plan_design_proposal]
    plan_design_proposal.profile = profile
    profile.benefit_sponsorships = [benefit_sponsorship]
    benefit_sponsorship.benefit_applications = [benefit_application]
    benefit_application.benefit_groups << benefit_group
    plan_design_organization.save!
    expect(BenefitSponsors::Organizations::Organization.all.count).to eq(2)
    expect(BenefitSponsors::Organizations::Organization.all.where(legal_name: "Broadcasting llc").first.present?).to eq(true)
  end

  let(:given_task_name) { "golden_seed" }
  subject { GoldenSeed.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end

    describe "instance variables" do
      before :each do
        ENV['coverage_start_on'] = "01/01/2020"
        ENV['coverage_end_on'] = "01/01/2021"
        subject.migrate
      end

      it "sets organization_collection as instance variable" do
        expect(subject.get_default_organizations.last).to eq(plan_design_organization)
      end

      it "sets benefit_sponsorships as instance variable" do
        expect(subject.get_benefit_sponsorships_of_organizations.last).to eq(plan_design_organization.active_benefit_sponsorship)
      end
      it "sets benefit_applications as instance variable" do
        expect(subject.get_benefit_applications_of_sponsorships.last).to eq(plan_design_organization.active_benefit_sponsorship.benefit_applications.last)
      end
    end
  end

  describe "updating benefit applications", dbclean: :after_each do
    before :each do
      ['coverage_start_on', 'coverage_end_on'].each do |var|
        ENV[var] = nil
      end
    end

    it "should run without errors" do
      expect { subject.migrate }.not_to raise_error
    end

    describe "requirements" do
      before :each do
        ['coverage_start_on', 'coverage_end_on'].each do |var|
          ENV[var] = nil
        end
      end

      it "should modify benefit application coverage start_on" do

      end

      it "should modify benefit application coverage end_on" do

      end

      it "should modify benefit application open_enrollment_start_on" do

      end

      it "should modify benefit application open_enrollment_end_on" do


      end

      it "should modify recalculate the appropriate prices" do

      end
    end
  end
end
