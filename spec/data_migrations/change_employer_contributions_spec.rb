require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require File.join(Rails.root, "app", "data_migrations", "change_employer_contributions")

describe ChangeEmployerContributions, dbclean: :after_each do
  let(:given_task_name) { "change_employer_contributions" }
  subject { ChangeEmployerContributions.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "changing employer contributions for health benefits" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    let!(:application) {initial_application}
    let!(:employer_profile) {benefit_sponsorship.profile}
    let(:organization) { employer_profile.organization}
    let!(:benefit_package) {initial_application.benefit_packages.first}

    before(:each) do
      allow(ENV).to receive(:[]).with("fein").and_return(organization.fein)
      allow(ENV).to receive(:[]).with("aasm_state").and_return(application.aasm_state)
      allow(ENV).to receive(:[]).with("relationship_name").and_return(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.display_name)
      allow(ENV).to receive(:[]).with("contribution_factor").and_return(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.contribution_factor - 0.5)
      allow(ENV).to receive(:[]).with("is_offered").and_return(true)
      allow(ENV).to receive(:[]).with("coverage_kind").and_return("health")
    end

    it "should change the employee contribution" do
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.contribution_factor).to eq 1.0
      subject.migrate
      benefit_package.reload
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.contribution_factor).to eq 0.5
    end

    it "should not change the other relationships contributions" do
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels[1].contribution_factor).to eq 0.8
      subject.migrate
      benefit_package.reload
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels[1].contribution_factor).to eq 0.8
    end

    it "should offer benefits" do
      benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.update_attribute(:is_offered, false)
      subject.migrate
      benefit_package.reload
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.is_offered).to eq true
    end

    it "should change the is offered attributes for the given relationship" do
      benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.update_attribute(:is_offered, false)
      subject.migrate
      benefit_package.health_sponsored_benefit.sponsor_contribution.reload
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels.first.is_offered).to eq true
    end

    it "should not change the is_offered attribute for other relationship" do
      benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels[1].update_attribute(:is_offered, false)
      subject.migrate
      benefit_package.health_sponsored_benefit.sponsor_contribution.reload
      expect(benefit_package.health_sponsored_benefit.sponsor_contribution.contribution_levels[1].is_offered).to eq false
    end
  end

  # Pending work for dental sponsored benefit, please have this fixed once the dental has made into prod.
  describe "changing employer contributions for dental benefits", :if => Settings.aca.dental_market_enabled do

    let(:benefit_group)     { FactoryGirl.create(:benefit_group, :with_dental_benefits, plan_year: plan_year)}

    before(:each) do
      allow(ENV).to receive(:[]).with("fein").and_return(employer_profile.parent.fein)
      allow(ENV).to receive(:[]).with("aasm_state").and_return(plan_year.aasm_state)
      allow(ENV).to receive(:[]).with("relationship").and_return(benefit_group.dental_relationship_benefits.first.relationship)
      allow(ENV).to receive(:[]).with("premium").and_return(benefit_group.dental_relationship_benefits.first.premium_pct + 5)
      allow(ENV).to receive(:[]).with("offered").and_return(benefit_group.dental_relationship_benefits.first.offered)
      allow(ENV).to receive(:[]).with("coverage_kind").and_return("dental")
    end

    it "should change the employee contribution" do
      expect(benefit_group.dental_relationship_benefits.first.premium_pct).to eq 49
      subject.migrate
      benefit_group.reload
      expect(benefit_group.dental_relationship_benefits.first.premium_pct).to eq 54
    end

    it "should not change the other relationships contributions" do
      expect(benefit_group.dental_relationship_benefits[1].premium_pct).to eq 40
      subject.migrate
      benefit_group.reload
      expect(benefit_group.dental_relationship_benefits[1].premium_pct).to eq 40
    end

    it "should offer benefits" do
      benefit_group.dental_relationship_benefits.first.update_attribute(:offered, false)
      subject.migrate
      benefit_group.reload
      expect(benefit_group.relationship_benefits.first.offered).to eq true
    end

    it "should not offer benefits for other relationships" do
      benefit_group.dental_relationship_benefits[1].update_attribute(:offered, false)
      subject.migrate
      benefit_group.reload
      expect(benefit_group.dental_relationship_benefits[1].offered).to eq false
    end
  end
end
