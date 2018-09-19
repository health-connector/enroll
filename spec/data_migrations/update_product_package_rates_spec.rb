require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require File.join(Rails.root, "app", "data_migrations", "update_product_package_rates")

describe UpdateEmployeeRoleId, dbclean: :after_each do
  
  let(:given_task_name) { "update_product_package_rates" }
  subject { UpdateProductPackageRates.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "update product package rates", dbclean: :after_each do

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"





    # let(:current_effective_date)  { TimeKeeper.date_of_record }
    # let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    # let(:benefit_market)      { site.benefit_markets.first }
    # let!(:rating_area)   { FactoryGirl.create_default :benefit_markets_locations_rating_area }
    # let!(:service_area)  { FactoryGirl.create_default :benefit_markets_locations_service_area }
    # let!(:security_question)  { FactoryGirl.create_default :security_question }
    # let(:start_on)  { current_effective_date.prev_month }
    # let(:effective_period)  { start_on..start_on.next_year.prev_day }
    # let(:benefit_sponsorship) { BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer_organization.employer_profile) }
    let!(:application) {initial_application}
    let!(:employer_profile) {benefit_sponsorship.profile}
    let(:organization) { employer_profile.organization}
    let!(:benefit_package) {initial_application.benefit_packages.first}
    let(:hios_id) {initial_application.benefit_sponsor_catalog.product_packages.first.products.first.hios_id}
    let(:changed_effective_period) {initial_application.start_on.prev_quarter.beginning_of_quarter..initial_application.start_on.prev_quarter.end_of_quarter}
    # let!(:employer_attestation)     { BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved") }
    # let!(:benefit_sponsorship) do
    #   FactoryGirl.create(
    #     :benefit_sponsors_benefit_sponsorship,
    #     :with_rating_area,
    #     :with_service_areas,
    #     supplied_rating_area: rating_area,
    #     service_area_list: [service_area],
    #     organization: organization,
    #     profile_id: organization.profiles.first.id,
    #     benefit_market: site.benefit_markets[0],
    #     employer_attestation: employer_attestation)
    # end
    # let!(:benefit_sponsor_catalog) { FactoryGirl.create(:benefit_markets_benefit_sponsor_catalog, service_areas: [service_area]) }
    

    # let!(:issuer_profile)  { FactoryGirl.create :benefit_sponsors_organizations_issuer_profile}
    # let!(:product_package_kind) { :single_issuer }
    # let!(:update_product_package) { benefit_sponsor_catalog.product_packages.where(package_kind: product_package_kind).first.update_attributes(package_kind: :single_product) }

    # let!(:product_package) { benefit_sponsor_catalog.product_packages.where(package_kind: :single_product).first}
    # let!(:products){product_package.products.update_all(product_package_kinds: [:single_product])}
    let!(:product) { FactoryGirl.create(:benefit_markets_products_health_products_health_product,
                      hios_id: hios_id,     
                      application_period: Date.new(initial_application.start_on.year,1, 1)..Date.new(initial_application.start_on.year, 12, 31)
                    )}
    # let!(:product2) {product_package.products.last}

    # let!(:benefit_package) { FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: benefit_application, product_package: product_package) }
    # let(:benefit_group_assignment) {FactoryGirl.build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_application.benefit_package)}

    let!(:employee_role) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person, census_employee_id: census_employee.id) }
    let!(:benefit_group_assignment) {FactoryGirl.build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_package)}
    let!(:census_employee) { FactoryGirl.create(:census_employee,
      employer_profile_id: nil,
      benefit_sponsors_employer_profile_id: employer_profile.id,
      benefit_sponsorship: initial_application.benefit_sponsorship,
      benefit_group_assignments: [benefit_group_assignment]
    )}
    let(:person) { FactoryGirl.create(:person) }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person)}

    let!(:hbx_enrollment) do
      FactoryGirl.create(:hbx_enrollment,
                         household: family.active_household,
                         kind: "employer_sponsored",
                         employee_role_id: employee_role.id,
                         sponsored_benefit_package_id: benefit_package.id,
                         benefit_group_assignment_id: benefit_group_assignment.id,
                         sponsored_benefit_id: benefit_package.health_sponsored_benefit.id,
                         aasm_state: 'shopping'
      )
    end
    before(:each) do
      ENV["feins"] = "123456789"
    end

    it "should update the premium tables on the product" do
      binding.pry
      initial_application.benefit_sponsor_catalog.product_packages.first.products.first.premium_tables.first.update_attributes!(effective_period:changed_effective_period)
      subject.migrate
      binding.pry
      expect(initial_application.benefit_sponsor_catalog.product_packages.first.products.first.premium_tables).to eq product.premium_tables
    end
  end
end