# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

RSpec.describe SponsoredBenefits::Organizations::PlanDesignProposalsController, type: :controller, dbclean: :around_each do
  routes { SponsoredBenefits::Engine.routes }

  let(:current_person) { FactoryBot.create(:person) }
  let(:datatable) { double(:datatable) }
  let(:sponsor) { double(:sponsor, id: '5ac4cb58be0a6c3ef400009a', sic_code: '1111') }
  let(:active_user) { FactoryBot.create(:user, person: current_person) }
  let!(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:broker_agency_organization1) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, legal_name: 'First Legal Name', site: site) }
  let!(:broker_agency_profile) { broker_agency_organization1.broker_agency_profile}
  let!(:broker_role) { FactoryBot.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, person: current_person) }

  before do
    allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(TimeKeeper.date_of_record.year, 10,1))
    benefit_application
    allow(subject).to receive(:current_person).and_return(current_person)
    allow(subject).to receive(:active_user).and_return(active_user)
    allow(current_person).to receive(:broker_role).and_return(broker_role)
    allow(active_user).to receive(:has_hbx_staff_role?).and_return(false)
    allow(broker_role).to receive(:broker_agency_profile_id).and_return(plan_design_organization.owner_profile_id)
    allow(subject).to receive(:effective_datatable).and_return(datatable)
    allow(subject).to receive(:employee_datatable).and_return(datatable)
    allow(broker_role).to receive(:benefit_sponsors_broker_agency_profile_id).and_return(plan_design_organization.owner_profile_id)
    allow(controller).to receive(:set_broker_agency_profile_from_user).and_return(plan_design_organization.broker_agency_profile)
  end

  after do
    allow(TimeKeeper).to receive(:date_of_record).and_call_original
  end

  describe '#claim', dbclean: :after_each do

    let(:site) do
      FactoryBot.create(
        :benefit_sponsors_site,
        :with_benefit_market,
        :with_benefit_market_catalog_and_product_packages,
        :as_hbx_profile,
        Settings.site.key
      )
    end

    let(:owner_profile) { broker_agency_profile }

    let(:plan_design_organization) do
      FactoryBot.create(
        :sponsored_benefits_plan_design_organization,
        owner_profile_id: owner_profile.id,
        sponsor_profile_id: sponsor_profile.id,
        broker_agency_profile_id: broker_agency_profile.id
      )
    end

    let(:plan_design_proposal) do
      FactoryBot.create(
        :plan_design_proposal,
        :with_profile,
        plan_design_organization: plan_design_organization
      ).tap do |proposal|
        sponsorship = proposal.profile.benefit_sponsorships.first
        sponsorship.initial_enrollment_period = benefit_sponsorship_enrollment_period
        sponsorship.save
      end
    end

    let(:broker_agency_profile) do
      FactoryBot.create(
        :benefit_sponsors_organizations_general_organization,
        :with_broker_agency_profile,
        site: site
      ).profiles.first
    end

    let(:current_effective_date){ TimeKeeper.date_of_record.next_month.beginning_of_month }
    let(:benefit_sponsorship_enrollment_period) { current_effective_date..current_effective_date.next_year.prev_day }

    let(:benefit_sponsorship) { proposal_profile.benefit_sponsorships.first }
    let(:prospect_benefit_sponsorship) { prospect_proposal_profile.benefit_sponsorships.first}

    let(:benefit_application) do
      FactoryBot.create(
        :plan_design_benefit_application,
        :with_benefit_group,
        effective_period: current_effective_date..current_effective_date.next_year.prev_day,
        benefit_sponsorship: benefit_sponsorship
      )
    end

    let(:employer_profile) { sponsor_profile }

    let(:reference_plan_for_benefit_group) do
      p_package = product_package('single_plan', :health)
      product = p_package.products[0]
      plan = FactoryBot.create(:plan, :with_premium_tables, coverage_kind: "health", active_year: current_effective_date.year, hios_id: product.hios_id)
      plan
    end

    let!(:benefit_group) do
      benefit_application.benefit_groups.first
      bg = benefit_application.benefit_groups.first
      bg.reference_plan = reference_plan_for_benefit_group
      bg.elected_plans = [reference_plan_for_benefit_group]
      bg.save!
      bg
    end

    let(:sponsor_profile) { organization.employer_profile }

    let(:organization) do
      org = FactoryBot.create(:benefit_sponsors_organizations_general_organization, "with_aca_shop_#{Settings.site.key}_employer_profile".to_sym, site: site)
      bs = org.employer_profile.add_benefit_sponsorship
      bs.save
      org
    end

    let(:sponsor_profile_benefit_sponsorship) { organization.active_benefit_sponsorship }

    let(:proposal_profile) { plan_design_proposal.profile }

    let(:published_plan_design_proposal) do
      pdp = plan_design_proposal
      pdp.publish!
      pdp
    end

    let!(:update_address) do
      address = organization.employer_profile.office_locations.first.address
      address.zip = plan_design_organization.office_locations[0].zip
      address.county = plan_design_organization.office_locations[0].county
      address.save
    end

    let(:benefit_sponsorship_enrollment_period) do
      begin_on = SponsoredBenefits::BenefitApplications::BenefitApplication.calculate_start_on_dates[0]
      end_on = begin_on + 1.year - 1.day
      begin_on..end_on
    end

    def product_package(pp_kind, kind)
      product_packages = site.benefit_markets[0].benefit_market_catalogs.last.product_packages.by_product_kind(kind)
      case pp_kind
      when 'single_plan'
        product_packages.by_package_kind(:single_product).first
      when 'single_carrier'
        product_packages.by_package_kind(:single_issuer).first
      when 'metal_level'
        product_packages.by_package_kind(:metal_level).first
      end
    end

    before :each do
      sponsor_profile.broker_agency_accounts << BenefitSponsors::Accounts::BrokerAgencyAccount.new(benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, writing_agent_id: broker_role.id, start_on: Time.now, is_active: true)
      sign_in(active_user)
      get :claim, params: { employer_profile_id: organization.employer_profile.id, claim_code: published_plan_design_proposal.claim_code}
    end

    it 'should claim the code successfully' do
      sponsor_profile_benefit_sponsorship.organization.reload
      applications = sponsor_profile_benefit_sponsorship.reload.benefit_applications
      expect(applications.count).to eq 1
      expect(applications.first.benefit_application_items.size).to eq 1
    end

    it 'should show success flash message' do
      expect(flash[:notice]).to eq 'Code claimed with success. Your Plan Year has been created.'
    end
  end
end