# frozen_string_literal: true

require "rails_helper"

RSpec.describe "components/benefit_sponsors/app/views/benefit_sponsors/profiles/employers/employer_profiles/my_account/home_tab.html.slim" do

  context "employer profile dashboard with current plan year" do

    let(:start_on){TimeKeeper.date_of_record.beginning_of_year}
    let(:end_on){TimeKeeper.date_of_record.end_of_year}
    let(:end_on_negative){ TimeKeeper.date_of_record.beginning_of_year - 2.years }
    let(:active_employees) { double("CensusEmployee", count: 10) }
    let(:mock_user) do
      instance_double(
        "User",
        has_hbx_staff_role?: false,  # Adjust this as needed
        # Add any other necessary methods and return values
      )
    end


    def new_organization
      instance_double(
        "Organization",
        office_locations: new_office_locations
      )
    end

    def office_location
      random_value = rand(999_999_999)
      instance_double(
        "OfficeLocation",
        address: new_address(random_value),
        phone: new_phone(random_value)
      )
    end

    def new_address(random_value)
      double(
        "Address",
        kind: "test#{random_value}",
        to_html: "test"
      )
    end

    def new_phone(random_value)
      double(
        "Phone",
        kind: "test#{random_value}"
      )
    end

    def broker_agency_account
      instance_double(
        "BrokerAgencyAccount",
        is_active: true,
        writing_agent: broker_role
      )
    end

    def employer_profile
      instance_double(
        "EmployerProfile",
        legal_name: "My silly name",
        organization: new_organization,
        fein: "098111000",
        entity_kind: "my entity kind",
        broker_agency_profile: new_broker_agency_profile,
        published_plan_year: plan_year
      )
    end

    def new_broker_agency_profile
      instance_double(
        "BrokerAgencyProfile",
        legal_name: "my broker legal name",
        primary_broker_role: broker_role
      )
    end

    def carrier_profile
      random_value = rand(999_999_999)
      double(
        "CarrierProfile",
        legal_name: "legal_name#{random_value}"
      )
    end

    def reference_plan_1
      double(
        "Plan",
        name: "name_1",
        plan_type: "ppo",
        metal_level: "metal_level_1",
        carrier_profile: carrier_profile,
        coverage_kind: 'health',
        active_year: TimeKeeper.date_of_record.beginning_of_year,
        dental_level: 'high'
      )
    end

    def reference_plan_2
      double(
        "Plan",
        name: "name_2",
        plan_type: "",
        metal_level: "metal_level_2",
        carrier_profile: carrier_profile,
        coverage_kind: 'dental',
        active_year: TimeKeeper.date_of_record.beginning_of_year,
        dental_level: 'high'
      )
    end

    def benefit_group_1
      double(
        "BenefitGroup",
        title: "title_1",
        effective_on_kind: "first_of_month",
        effective_on_offset: "30",
        plan_option_kind: "plan_option_kind_1",
        description: "my first benefit group",
        relationship_benefits: [relationship_benefits],
        reference_plan: reference_plan_1,
        reference_plan_id: double("id"),
        dental_reference_plan: reference_plan_1,
        sponsored_benefits: [sponsored_benefit],
        dental_reference_plan_id: "498523982893",
        monthly_employer_contribution_amount: "monthly_employer_contribution_amount_1",
        monthly_min_employee_cost: "monthly_min_employee_cost_1",
        monthly_max_employee_cost: "monthly_max_employee_cost_1",
        id: "9813829831293",
        is_offering_dental?: false,
        dental_plan_option_kind: "single_plan",
        elected_dental_plan_ids: [],
        elected_dental_plans: [],
        dental_relationship_benefits: [relationship_benefits],
        sole_source?: false
      )
    end

    def benefit_group_2
      double(
        "BenefitGroup",
        title: "title_2",
        effective_on_kind: "date_of_hire",
        effective_on_offset: "0",
        plan_option_kind: "plan_option_kind_2",
        description: "my first benefit group",
        relationship_benefits: [relationship_benefits],
        reference_plan: reference_plan_2,
        reference_plan_id: double("id"),
        dental_reference_plan: reference_plan_2,
        sponsored_benefits: [sponsored_benefit],
        dental_reference_plan_id: "498523982893",
        monthly_employer_contribution_amount: "monthly_employer_contribution_amount_2",
        monthly_min_employee_cost: "monthly_min_employee_cost_2",
        monthly_max_employee_cost: "monthly_max_employee_cost_2",
        id: "9456349532",
        is_offering_dental?: true,
        dental_plan_option_kind: "single_plan",
        elected_dental_plan_ids: [],
        elected_dental_plans: [],
        dental_relationship_benefits: [relationship_benefits],
        sole_source?: false
      )
    end

    def relationship_benefits
      random_value = rand(0..100)
      double(
        "RelationshipBenefit",
        offered: random_value.even?,
        relationship: "relationship;#{random_value}",
        premium_pct: random_value
      )
    end

    def plan_year
      double(
        "PlanYear",
        start_on: start_on,
        end_on: end_on,
        open_enrollment_start_on: PlanYear.calculate_open_enrollment_date(start_on)[:open_enrollment_start_on],
        open_enrollment_end_on: PlanYear.calculate_open_enrollment_date(start_on)[:open_enrollment_end_on],
        eligible_to_enroll_count: 4,
        covered_count: 4,
        waived_count: 4,
        total_enrolled_count: 10,
        enrollment_progress_bar: 2,
        progressbar_covered_count: 3,
        employee_participation_percent: 40,
        progressbar_enrolled_non_business_owner_members: Array.new(10).map{|_i| double },
        hbx_enrollments: [hbx_enrollment],
        additional_required_participants_count: 5,
        benefit_groups: benefit_groups,
        aasm_state: 'draft',
        predecessor_id: nil,
        employee_participation_ratio_minimum: 0.75,
        employer_profile: double(census_employees: double(active: active_employees))
      )
    end

    def broker_role
      instance_double(
        "BrokerRole",
        person: new_person,
        npn: 723_232_3
      )
    end

    def new_person
      random_value = rand(999_999_999)
      instance_double(
        "Person",
        full_name: "my full name",
        phones: [new_phone(random_value)],
        emails: [new_email]
      )
    end

    def new_email
      instance_double(
        "Email",
        address: "test@example.com"
      )
    end

    def hbx_enrollment
      instance_double(
        "HbxEnrollment",
        total_premium: double("total_premium"),
        total_employer_contribution: double("total_employer_contribution"),
        total_employee_cost: double("total_employee_cost")
      )
    end

    def sponsored_benefit
      double("BenefitSponsors::SponsoredBenefits::SponsoredBenefit",
             product_kind: "rspec_kind",
             reference_product: reference_product,
             product_package_kind: :single_product,
             pricing_determinations: [],
             sponsor_contribution: sponsored_contribution)
    end

    def sponsored_contribution
      contribution_levels = double(
        "RelationShipBenefits",
        is_offered: true,
        display_name: "rspec_display_name",
        contribution_pct: 200.00
      )
      double("SponsoredContributoon", contribution_levels: [contribution_levels])
    end

    def reference_product
      double(
        "BenefitMarkets::Products::Product",
        kind: :metal_level,
        name: "rspec-name",
        product_type: "rspec-product",
        metal_level: "Rspec-level",
        issuer_profile: double("BenefitSponsors::Organizations::IssuerProfile", legal_name: "rspec_legal_name")
      )
    end

    let(:new_office_locations){[office_location,office_location]}
    let(:current_plan_year){employer_profile.published_plan_year}
    let(:benefit_groups){ [benefit_group_1, benefit_group_2] }
    let(:cost_estimator) { double("BenefitSponsors::Services::SponsoredBenefitCostEstimationService")}
    let(:estimator) do
      {
        estimated_total_cost: 100,
        estimated_enrollee_minimum: 33,
        estimated_enrollee_maximum: 100
      }
    end

    before :each do
      view.extend BenefitSponsors::Engine.routes.url_helpers
      allow(::BenefitSponsors::Services::SponsoredBenefitCostEstimationService).to receive(:new).and_return(cost_estimator)
      allow(cost_estimator).to receive(:calculate_estimates_for_home_display).and_return(estimator)
      allow(view).to receive(:pundit_class).and_return(double("EmployerProfilePolicy", updateable?: true))
      allow(view).to receive(:policy_helper).and_return(double("EmployerProfilePolicy", updateable?: true))


      assign :employer_profile, employer_profile
      assign :hbx_enrollments, [hbx_enrollment]
      assign :current_plan_year, employer_profile.published_plan_year
      assign :participation_minimum, 0
      assign :broker_agency_accounts, [broker_agency_account]
      controller.request.path_parameters[:id] = "11111111"
    end

    context "when employer setting is enabled" do
      it "should display the employer external links advertisement" do
        allow(view).to receive(:current_user).and_return(mock_user)
        EnrollRegistry[:add_external_links].feature.stub(:is_enabled).and_return(true)
        EnrollRegistry[:add_external_links].setting(:employer_display).stub(:item).and_return(true)

        render "benefit_sponsors/profiles/employers/employer_profiles/my_account/home_tab"

        expect(rendered).to match(/Save 15% on the cost of your health insurance contributions with our ConnectWell rebate program./i)
        expect(rendered).to include("href=\"https://www.mahealthconnector.org/business/employers/connectwell-for-employers")
      end
    end

    context "when employer setting is disabled" do
      it "should not display the employer external links advertisement" do
        allow(view).to receive(:current_user).and_return(mock_user)
        EnrollRegistry[:add_external_links].feature.stub(:is_enabled).and_return(true)
        EnrollRegistry[:add_external_links].setting(:employer_display).stub(:item).and_return(false)

        render "benefit_sponsors/profiles/employers/employer_profiles/my_account/home_tab"

        expect(rendered).not_to match(/Save 15% on the cost of your health insurance contributions with our ConnectWell rebate program./i)
        expect(rendered).not_to include("href=\"https://www.mahealthconnector.org/business/employers/connectwell-for-employers")
      end
    end

    context "when user is an admin" do
      before do
        allow(mock_user).to receive(:has_hbx_staff_role?).and_return(true)
        allow(view).to receive(:current_user).and_return(mock_user)
        render "benefit_sponsors/profiles/employers/employer_profiles/my_account/home_tab"
      end

      it "renders the 'Run Eligibility Check' button" do
        expect(rendered).to have_selector('input#eligibilityCheckButton[value="Run Eligibility Check"]')
      end
    end

    context "when user is not an admin" do
      before do
        allow(mock_user).to receive(:has_hbx_staff_role?).and_return(false)
        allow(view).to receive(:current_user).and_return(mock_user)
        render "benefit_sponsors/profiles/employers/employer_profiles/my_account/home_tab"
      end

      it "does not render the 'Run Eligibility Check' button" do
        expect(rendered).not_to have_selector('input#eligibilityCheckButton[value="Run Eligibility Check"]')
      end
    end
  end
end
