require 'rails_helper'

RSpec.describe CensusMember, :dbclean => :after_each do
  it { should validate_presence_of :first_name }
  it { should validate_presence_of :last_name }
  it { should validate_presence_of :dob }
  let(:site)                    { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:benefit_market)          { site.benefit_markets.first }
  let(:employer_organization)   { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:benefit_sponsorship)    { BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer_organization.employer_profile) }
  let(:benefit_sponsor_catalog) { FactoryGirl.create(:benefit_markets_benefit_sponsor_catalog, service_areas: [service_area]) }
  let(:rating_area)  { create_default(:benefit_markets_locations_rating_area) }
  let(:service_area) { create_default(:benefit_markets_locations_service_area) }
  let(:sic_code)      { "001" }

  let!(:employer_profile) {benefit_sponsorship.profile}
  let(:renewal_effective_date) { (TimeKeeper.date_of_record + 2.months).beginning_of_month }
  let(:current_effective_date) { renewal_effective_date.prev_year }
  let(:effective_period) { current_effective_date..current_effective_date.next_year.prev_day }
  let(:package_kind)            { :single_issuer }
  let!(:initial_application) { create(:benefit_sponsors_benefit_application, benefit_sponsor_catalog: benefit_sponsor_catalog, effective_period: effective_period,benefit_sponsorship:benefit_sponsorship, aasm_state: :active) }
  let(:product_package)           { initial_application.benefit_sponsor_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
  let(:benefit_package)   { create(:benefit_sponsors_benefit_packages_benefit_package, health_sponsored_benefit: true, product_package: product_package, benefit_application: initial_application) }
  let(:benefit_group_assignment) { FactoryGirl.build(:benefit_group_assignment, start_on: benefit_package.start_on, benefit_group_id:nil, benefit_package_id: benefit_package.id, is_active:true)}
  let!(:census_employee) { FactoryGirl.create(:census_employee, employer_profile_id: nil, benefit_sponsors_employer_profile_id: employer_profile.id, benefit_sponsorship: benefit_sponsorship, :benefit_group_assignments => [benefit_group_assignment]) }


  it "sets gender" do
    census_employee.gender = "MALE"
    expect(census_employee.gender).to eq "male"
  end

  it "sets date of birth" do
    census_employee.date_of_birth = "1980-12-12"
    expect(census_employee.dob).to eq "1980-12-12".to_date
  end

  context "dob" do
    before(:each) do
      census_employee.date_of_birth = "1980-12-01"
    end

    it "dob_string" do
      expect(census_employee.dob_to_string).to eq "19801201"
    end

    it "date_of_birth" do
      expect(census_employee.date_of_birth).to eq "12/01/1980"
    end

    context "dob more than 110 years ago" do
      before(:each) do
        census_employee.dob = 111.years.ago
      end

      it "generate validation error" do
        expect(census_employee.valid?).to be_falsey
        expect(census_employee.errors.full_messages).to include("Dob date cannot be more than 110 years ago")
      end
    end
  end

  context "validate of date_of_birth_is_past" do
    it "should invalid" do
      dob = (Date.today + 10.days)
      census_employee.date_of_birth = dob.strftime("%Y-%m-%d")
      expect(census_employee.save).to be_falsey
      expect(census_employee.errors[:dob].any?).to be_truthy
      expect(census_employee.errors[:dob].to_s).to match /future date: #{dob.to_s} is invalid date of birth/
    end
  end

  context "without a gender" do
    it "should be invalid" do
      expect(census_employee.valid?).to eq true
      census_employee.gender = nil
      expect(census_employee.valid?).to eq false
      expect(census_employee).to have_errors_on(:gender)
    end
  end
end
