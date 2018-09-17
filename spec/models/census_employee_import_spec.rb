require 'rails_helper'

RSpec.describe CensusEmployeeImport, :type => :model, :dbclean => :after_each do

  let(:tempfile) { double("", path: 'spec/test_data/census_employee_import/DCHL Employee Census.xlsx') }
  let(:file) {
    double("", :tempfile => tempfile)
  }
  let(:sheet) {
    Roo::Spreadsheet.open(file.tempfile.path).sheet(0)
  }
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
  let(:subject) {
    CensusEmployeeImport.new({file: file, employer_profile: employer_profile})
  }

  context "initialize without employer_role and file" do
    it "throws exception" do
      expect { CensusEmployeeImport.new() }.to raise_error(ArgumentError)
    end
  end

  context "initialize with employer_role and file" do
    it "should not throw an exception" do
      expect { CensusEmployeeImport.new({file: file, employer_profile: employer_profile}) }.to_not raise_error
    end
  end

  it "should validate headers" do
    sheet_header_row = sheet.row(1)
    column_header_row = sheet.row(2)
    expect(subject.header_valid?(sheet_header_row) && subject.column_header_valid?(column_header_row)).to be_truthy
  end

  context "One employee with one dependent" do
    it "should added a employee with a dependent" do
      expect(subject.save).to be_truthy
      expect(subject.load_imported_census_employees.count).to eq(2) # 1 employee + 1 dependent
      expect(subject.load_imported_census_employees.first).to be_a CensusEmployee
      expect(subject.load_imported_census_employees.first.census_dependents.size).to eq(1)
      expect(subject.load_imported_census_employees.last).to be_a CensusDependent
    end

    it "should save the employee with address_kind_even_without_input_address_kind" do
      expect(subject.save).to be_truthy
      expect(subject.load_imported_census_employees.first.address.kind).to eq 'home'
      expect(subject.load_imported_census_employees.first.address.present?).to be_truthy
      expect(subject.load_imported_census_employees.first.address.address_2.present?).to be_truthy
    end

    it "should save the employee & dependent with correct attributes" do
      expect(subject.save).to be_truthy
      expect(subject.load_imported_census_employees.first.first_name).to eq "test"
      expect(subject.load_imported_census_employees.first.last_name).to eq "test"
      expect(subject.load_imported_census_employees.first.gender).to eq "male"
      expect(subject.load_imported_census_employees.first.census_dependents.first.first_name).to eq "test2"
      expect(subject.load_imported_census_employees.first.census_dependents.first.last_name).to eq "test2"
      expect(subject.load_imported_census_employees.first.census_dependents.first.employee_relationship).to eq "spouse"
      expect(subject.load_imported_census_employees.first.census_dependents.first.gender).to eq "female"
    end

  end

  context "relationship field is empty" do

    let(:tempfile) { double("", path: 'spec/test_data/census_employee_import/DCHL Employee Census 2.xlsx') }
    let(:file) {
      double("", :tempfile => tempfile)
    }
    let(:sheet) {
      Roo::Spreadsheet.open(file.tempfile.path).sheet(0)
    }
    let(:subject) {
      CensusEmployeeImport.new({file: file, employer_profile: employer_profile})
    }

    it "should not add the 2nd employee/dependent (as relationship is missing)" do
      expect(subject.save).to be_falsey
      expect(subject.load_imported_census_employees.count).to eq(1) # 1 employee + no dependents
      expect(subject.load_imported_census_employees.first).to be_a CensusEmployee
      expect(subject.load_imported_census_employees.first.census_dependents.count).to eq(0)
      expect(subject.load_imported_census_employees.first.last_name).to eq "panther1"
    end

    it "should not save successfully" do
      expect(subject.save).to be_falsey
    end
  end

  context "terminate employee" do
    let(:tempfile) { double("", path: 'spec/test_data/census_employee_import/DCHL Employee Census 3.xlsx') }
    let(:file) { double("", :tempfile => tempfile) }
    let!(:census_employee) { FactoryGirl.create(:census_employee, employer_profile_id: nil, benefit_sponsors_employer_profile_id: employer_profile.id, benefit_sponsorship: benefit_sponsorship, :benefit_group_assignments => [benefit_group_assignment]) }

    context "employee does not exist" do
      it "should fail" do
        expect(subject.save).to be_falsey
        expect(subject.errors.messages[:base]).to include("Row 4: Employee/Dependent not found or not active")
        expect(subject.instance_variable_get("@terminate_queue").length).to eq(0)
      end
    end

    context "employee exists" do
      before do
        allow(subject).to receive(:find_employee).and_return(census_employee)
        allow(subject).to receive(:is_employee_terminable?).with(census_employee).and_return(true)
      end

      it "should save successfully" do
        expect(subject.save).to be_truthy
        expect(subject.load_imported_census_employees.count).to eq(1)
        expect(subject.instance_variable_get("@terminate_queue").length).to eq(1)
      end
    end

  end
end
