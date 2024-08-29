# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Eligible::BuildEvidence, type: :model, dbclean: :after_each do
  let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
  let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
  let(:product)          { catalog.product_packages[0].products.first }
  let(:rating_area)    { product.premium_tables.first.rating_area }
  let(:user)             { FactoryBot.create(:user) }
  let!(:pvp) do
    BenefitMarkets::Operations::Pvp::FindOrCreate.new.call(
      product_id: product.id,
      rating_area_id: rating_area.id
    ).success
  end

  let(:required_params) do
    {
      subject: pvp.to_global_id,
      effective_date: Date.today,
      evidence_key: :shop_osse_evidence,
      evidence_value: evidence_value,
      event: event,
      evidence_record: evidence_record,
      current_user: user.to_global_id
    }
  end

  let(:evidence_value) { "false" }
  let(:event) { :move_to_denied }
  let(:evidence_record) { nil }

  context "with input params" do
    let(:event) { :move_to_initial }

    it "should build admin attested evidence options" do
      result = described_class.new.call(required_params)

      expect(result).to be_success
    end

    it "should build evidence options with :initial state" do
      evidence = described_class.new.call(required_params).success

      state_history = evidence[:state_histories].last
      expect(state_history[:event]).to eq(:move_to_not_approved)
      expect(state_history[:from_state]).to eq(:initial)
      expect(state_history[:to_state]).to eq(:not_approved)
      expect(state_history[:is_eligible]).to eq(false)
      expect(evidence[:is_satisfied]).to eq(false)
    end
  end

  context "with event approved" do
    let(:event) { :move_to_approved }
    let(:evidence_value) { "true" }

    it "should build evidence options with :approved state" do
      evidence = described_class.new.call(required_params).success

      state_history = evidence[:state_histories].last
      expect(state_history[:event]).to eq(:move_to_approved)
      expect(state_history[:from_state]).to eq(:initial)
      expect(state_history[:to_state]).to eq(:approved)
      expect(state_history[:is_eligible]).to eq(true)
      expect(evidence[:is_satisfied]).to eq(true)
    end
  end

  context "when existing evidence present" do
    let!(:pvp_eligibility) do
      service = BenefitMarkets::Services::PvpEligibilityService.new(
        product, user, {rating_areas: {rating_area.id => true}}
      )
      service.create_or_update_pvp_eligibilities

      pvp.reload.eligibilities.first
    end

    let(:evidence_record) { pvp_eligibility.evidences.last }

    it "should create state history in tandem with existing evidence" do
      evidence = described_class.new.call(required_params).success
      state_history = evidence[:state_histories].last
      expect(state_history[:event]).to eq(:move_to_denied)
      expect(state_history[:from_state]).to eq(:approved)
      expect(state_history[:to_state]).to eq(:denied)
      expect(state_history[:is_eligible]).to eq(false)
      expect(evidence[:is_satisfied]).to eq(false)
    end
  end
end