# frozen_string_literal: true

require "rails_helper"

RSpec.describe Operations::Eligible::BuildEligibility, type: :model, dbclean: :after_each do
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
      effective_date: TimeKeeper.datetime_of_record,
      evidence_key: :shop_pvp_evidence,
      evidence_value: evidence_value,
      event: event,
      eligibility_record: eligibility_record,
      current_user: user.to_global_id
    }
  end

  let(:evidence_value) { "false" }
  let(:event) { :move_to_denied }
  let(:eligibility_record) { nil }

  context "with input params" do
    let(:event) { :move_to_initial }

    it "should build admin attested evidence options" do
      result = described_class.new.call(required_params)

      expect(result).to be_success
    end

    it "should build evidence options with :initial state" do
      eligibility = described_class.new.call(required_params).success

      evidence = eligibility[:evidences].last
      eligibility_state_history = eligibility[:state_histories].last
      evidence_state_history = evidence[:state_histories].last

      expect(eligibility_state_history[:event]).to eq(:move_to_ineligible)
      expect(eligibility_state_history[:from_state]).to eq(:initial)
      expect(eligibility_state_history[:to_state]).to eq(:ineligible)
      expect(eligibility_state_history[:is_eligible]).to be_falsey

      expect(evidence_state_history[:event]).to eq(:move_to_not_approved)
      expect(evidence_state_history[:from_state]).to eq(:initial)
      expect(evidence_state_history[:to_state]).to eq(:not_approved)
      expect(evidence_state_history[:is_eligible]).to be_falsey
      expect(evidence_state_history[:updated_by]).to eq user.to_global_id.to_s

      expect(evidence[:is_satisfied]).to be_falsey
    end
  end

  context "with event approved" do
    let(:event) { :move_to_approved }
    let(:evidence_value) { "true" }

    it "should build evidence options with :approved state" do
      eligibility = described_class.new.call(required_params).success

      evidence = eligibility[:evidences].last
      eligibility_state_history = eligibility[:state_histories].last
      evidence_state_history = evidence[:state_histories].last

      expect(eligibility_state_history[:event]).to eq(:move_to_eligible)
      expect(eligibility_state_history[:from_state]).to eq(:initial)
      expect(eligibility_state_history[:to_state]).to eq(:eligible)
      expect(eligibility_state_history[:is_eligible]).to be_truthy

      expect(evidence_state_history[:event]).to eq(:move_to_approved)
      expect(evidence_state_history[:from_state]).to eq(:initial)
      expect(evidence_state_history[:to_state]).to eq(:approved)
      expect(evidence_state_history[:is_eligible]).to be_truthy
      expect(evidence_state_history[:updated_by]).to eq user.to_global_id.to_s

      expect(evidence[:is_satisfied]).to be_truthy
    end
  end
end