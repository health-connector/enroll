RSpec.describe SponsoredBenefits::Services::PlanCostService, type: :model, dbclean: :after_each do
  let!(:rating_area) { FactoryBot.create(:rating_area, zip_code: ofice_location.address.zip, county_name: ofice_location.address.county)}

  let(:plan_design_organization) do
    FactoryBot.create :sponsored_benefits_plan_design_organization,
      owner_profile_id: owner_profile.id,
      sponsor_profile_id: sponsor_profile.id
  end

  let(:plan_design_proposal) do
    FactoryBot.create(:plan_design_proposal,
      :with_profile,
      plan_design_organization: plan_design_organization
    ).tap do |proposal|
      sponsorship = proposal.profile.benefit_sponsorships.first
      sponsorship.initial_enrollment_period = benefit_sponsorship_enrollment_period
      sponsorship.save
    end
  end

  let(:ofice_location) { proposal_profile.primary_office_location }

  let(:proposal_profile) { plan_design_proposal.profile }

  let(:benefit_sponsorship_enrollment_period) do
    begin_on = SponsoredBenefits::BenefitApplications::BenefitApplication.calculate_start_on_dates[0]
    end_on = begin_on + 1.year - 1.day
    begin_on..end_on
  end

  let(:benefit_sponsorship) { proposal_profile.benefit_sponsorships.first }

  let(:benefit_application) do
    FactoryBot.create :plan_design_benefit_application,
      :with_benefit_group,
      benefit_sponsorship: benefit_sponsorship
  end

  let(:benefit_group) do
    benefit_application.benefit_groups.first.tap do |benefit_group|
      reference_plan_id = FactoryBot.create(:plan, :with_complex_premium_tables, :with_rating_factors).id
      benefit_group.update_attributes(reference_plan_id: reference_plan_id, plan_option_kind: 'single_carrier')
    end
  end

  let(:owner_profile) { broker_agency_profile }
  let(:broker_agency) { owner_profile.organization }
  let(:employer_profile) { sponsor_profile }
  let(:benefit_sponsor) { sponsor_profile.organization }

  let!(:plan_design_census_employee) do
    FactoryBot.create_list :plan_design_census_employee, 2,
      :with_random_age,
      benefit_sponsorship_id: benefit_sponsorship.id
  end

  let(:organization) { plan_design_organization.sponsor_profile.organization }

  let!(:current_effective_date) do
    (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year
  end

  let!(:broker_agency_profile) do
    if Settings.aca.state_abbreviation == "DC" # toDo
      FactoryBot.create(:broker_agency_profile)
    else
      FactoryBot.create(:benefit_sponsors_organizations_general_organization,
        :with_site,
        :with_broker_agency_profile
      ).profiles.first
    end
  end

  let!(:sponsor_profile) do
    FactoryBot.create(:employer_profile)
  end

  let!(:relationship_benefit) { benefit_group.relationship_benefits.first }
  let(:subject) { SponsoredBenefits::Services::PlanCostService.new(benefit_group: benefit_group)}

  it "should have multiple_rating_areas instance variable true" do
    expect(subject.instance_variable_get("@multiple_rating_areas")).to eq true
  end

  context "#monthly_employer_contribution_amount" do
    before :each do
      allow(Caches::PlanDetails).to receive(:lookup_rate_with_area).and_return 78.0 
    end
    it "should return total monthly employer contribution amount" do
      # Er contribution 80%. No.of Employees = 2
      expect(subject.monthly_employer_contribution_amount).to eq (0.8*2*78.0)
    end
  end

  context "#monthly_employee_costs" do

    before :each do
      allow(Caches::PlanDetails).to receive(:lookup_rate_with_area).and_return 78.0
      subject.plan = benefit_group.reference_plan
    end
    it "should return total monthly employee contribution amount" do
      # ER contribution is 80%. EE contribution is 20%
      expect(subject.monthly_employee_costs).to eq [0.2*78.0, 0.2*78.0]
    end
  end

  context "for dental plan" do

    let(:benefit_group) do
      benefit_application.benefit_groups.first.tap do |benefit_group|
        reference_plan_id = FactoryBot.create(:plan, :with_dental_coverage, :with_complex_premium_tables, :with_rating_factors).id
        benefit_group.update_attributes(dental_reference_plan_id: reference_plan_id)
      end
    end

    before :each do
      allow(Caches::PlanDetails).to receive(:lookup_rate_with_area).and_return 92.0
      @pcs = SponsoredBenefits::Services::PlanCostService.new(benefit_group: benefit_group)
      @pcs.plan = benefit_group.dental_reference_plan
    end
    it "should return dental reference plan" do
      expect(@pcs.reference_plan.dental?).to be_truthy
    end
  end

  context "3-child premium cap for dental plans" do
    let(:start_on) { benefit_sponsorship_enrollment_period.min }
    let(:dental_plan) do
      FactoryBot.create(:plan, :with_dental_coverage, :with_complex_premium_tables, :with_rating_factors)
    end
    let(:dental_benefit_group) do
      benefit_application.benefit_groups.first.tap do |bg|
        bg.dental_reference_plan_id = dental_plan.id
        bg.build_dental_relationship_benefits
        bg.dental_relationship_benefits.each do |rb|
          rb.premium_pct = case rb.relationship
                           when 'employee'       then 80.0
                           when 'child_under_26' then 75.0
                           else 0.0
                           end
        end
      end
    end
    let!(:employee_with_four_children) do
      FactoryBot.create(
        :plan_design_census_employee,
        benefit_sponsorship_id: benefit_sponsorship.id,
        dob: start_on - 43.years
      ).tap do |ce|
        [20, 18, 16, 14].each do |age|
          ce.census_dependents.create!(
            employee_relationship: 'child_under_26',
            dob: start_on - age.years,
            first_name: 'Kid',
            last_name: 'Test',
            gender: 'female'
          )
        end
      end
    end
    let(:service) do
      SponsoredBenefits::Services::PlanCostService.new(benefit_group: dental_benefit_group).tap do |s|
        s.plan = dental_plan
      end
    end

    before do
      Rails.cache.clear
      employee_with_four_children.reload
      allow(service).to receive(:active_census_employees).and_return([employee_with_four_children])
      allow(Caches::PlanDetails).to receive(:lookup_rate_with_area).and_return(20.0)
    end

    describe "#large_family_factor with a dental plan" do
      let(:children_oldest_first) do
        employee_with_four_children.reload.census_dependents
                                   .sort_by { |c| -c.age_on(start_on) }
      end

      it "returns 1.00 for the 1st oldest child under 21" do
        expect(service.large_family_factor(children_oldest_first[0], employee_with_four_children)).to eq 1.00
      end

      it "returns 1.00 for the 2nd oldest child under 21" do
        expect(service.large_family_factor(children_oldest_first[1], employee_with_four_children)).to eq 1.00
      end

      it "returns 1.00 for the 3rd oldest child under 21" do
        expect(service.large_family_factor(children_oldest_first[2], employee_with_four_children)).to eq 1.00
      end

      it "returns 0.00 for the 4th child under 21 - 3-child cap applies to dental same as health" do
        expect(service.large_family_factor(children_oldest_first[3], employee_with_four_children)).to eq 0.00
      end
    end

    describe "#monthly_employer_contribution_amount" do
      # With mocked rate 20.0 and 80% employee / 75% child_under_26 contribution:
      #   employee (age 43): min(1.00 x 20.0 x 80%, 20.0) x 1.00 = 16.00
      #   child age 20 (idx 0): min(1.00 x 20.0 x 75%, 20.0) x 1.00 = 15.00
      #   child age 18 (idx 1): 15.00
      #   child age 16 (idx 2): 15.00
      #   child age 14 (idx 3): min(0.00, 0.00) x 0.00 = 0.00  (3-child cap)
      #   -----------------------------------------------
      #   Correct total: 61.00
      #   Buggy total:   76.00 (all 4 children charged)
      it "charges the employer for only the 3 oldest children, excluding the 4th" do
        expect(service.monthly_employer_contribution_amount).to eq BigDecimal("61.0")
      end

      it "does not produce the inflated total that includes the 4th child's premium" do
        expect(service.monthly_employer_contribution_amount).not_to eq BigDecimal("76.0")
      end
    end
  end
end
