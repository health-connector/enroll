# frozen_string_literal: true

require "rails_helper"

RSpec.describe BenefitMarkets::Operations::Pvp::CreatePvpEligibility, type: :model, dbclean: :around_each do

  let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
  let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
  let(:product)          { catalog.product_packages[0].products.first }
  let(:rating_area)      { product.premium_tables.first.rating_area }
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
      evidence_key: :shop_pvp_evidence,
      evidence_value: evidence_value,
      current_user: user.to_global_id
    }
  end

  let(:evidence_value) { "false" }

  context "with input params" do
    it "should build admin attested evidence options" do
      result = subject.call(required_params)

      expect(result).to be_success
    end

    it "should create eligibility with :initial state evidence" do
      eligibility = subject.call(required_params).success

      evidence = eligibility.evidences.last
      eligibility_state_history = eligibility.state_histories.last
      evidence_state_history = evidence.state_histories.last

      expect(eligibility_state_history.event).to eq(:move_to_ineligible)
      expect(eligibility_state_history.from_state).to eq(:initial)
      expect(eligibility_state_history.to_state).to eq(:ineligible)
      expect(eligibility_state_history.is_eligible).to be_falsey

      expect(evidence_state_history.event).to eq(:move_to_not_approved)
      expect(evidence_state_history.from_state).to eq(:initial)
      expect(evidence_state_history.to_state).to eq(:not_approved)
      expect(evidence_state_history.is_eligible).to be_falsey
      expect(evidence.is_satisfied).to be_falsey
    end
  end

  context "with event approved" do
    let(:evidence_value) { "true" }

    it "should create eligibility with :approved state evidence" do
      eligibility = subject.call(required_params).success

      evidence = eligibility.evidences.last
      eligibility_state_history = eligibility.state_histories.last
      evidence_state_history = evidence.state_histories.last

      expect(eligibility_state_history.event).to eq(:move_to_eligible)
      expect(eligibility_state_history.from_state).to eq(:initial)
      expect(eligibility_state_history.to_state).to eq(:eligible)
      expect(eligibility_state_history.is_eligible).to be_truthy

      expect(evidence_state_history.event).to eq(:move_to_approved)
      expect(evidence_state_history.from_state).to eq(:initial)
      expect(evidence_state_history.to_state).to eq(:approved)
      expect(evidence_state_history.is_eligible).to be_truthy
      expect(evidence.is_satisfied).to be_truthy
    end
  end

  context "with event approved" do
    let(:evidence_value) { "false" }

    it "should create eligibility with :approved state evidence" do
      eligibility = subject.call(required_params).success

      evidence = eligibility.evidences.last
      eligibility_state_history = eligibility.state_histories.last
      evidence_state_history = evidence.state_histories.last

      expect(eligibility_state_history.event).to eq(:move_to_ineligible)
      expect(eligibility_state_history.from_state).to eq(:initial)
      expect(eligibility_state_history.to_state).to eq(:ineligible)
      expect(eligibility_state_history.is_eligible).to be_falsey

      expect(evidence_state_history.event).to eq(:move_to_not_approved)
      expect(evidence_state_history.from_state).to eq(:initial)
      expect(evidence_state_history.to_state).to eq(:not_approved)
      expect(evidence_state_history.is_eligible).to be_falsey
      expect(evidence.is_satisfied).to be_falsey
    end
  end

  context "when updating existing eligibility" do
    let(:evidence_value) { "true" }

    before do
      # Create initial eligibility
      @initial_result = subject.call(required_params)
    end

    it "should update the existing eligibility record" do
      # Update with new evidence
      updated_params = required_params.merge(evidence_value: "false")
      result = subject.call(updated_params)

      expect(result).to be_success
      eligibility = result.success

      # Should have multiple state histories (initial + update)
      expect(eligibility.state_histories.count).to be >= 2
      expect(eligibility.evidences.last.state_histories.count).to be >= 2
    end

    it "should maintain eligibility continuity" do
      initial_eligibility = @initial_result.success
      initial_id = initial_eligibility.id

      # Update eligibility
      updated_params = required_params.merge(evidence_value: "false")
      result = subject.call(updated_params)

      expect(result).to be_success
      updated_eligibility = result.success

      # Should update same record, not create new one
      expect(updated_eligibility.id).to eq(initial_id)
    end

    it "should append state histories on update" do
      initial_eligibility = @initial_result.success
      initial_state_count = initial_eligibility.state_histories.count

      # Update with opposite value
      updated_params = required_params.merge(evidence_value: "false")
      result = subject.call(updated_params)

      expect(result).to be_success
      eligibility = result.success

      # Should have more state histories
      expect(eligibility.state_histories.count).to be > initial_state_count
      expect(eligibility.current_state).to eq(:ineligible)
    end
  end

  context "validation failures" do
    it "should fail when evidence_key is missing" do
      params = required_params.except(:evidence_key)
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure).to include("evidence key missing")
    end

    it "should fail when evidence_value is missing" do
      params = required_params.except(:evidence_value)
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure).to include("evidence value missing")
    end

    it "should fail when effective_date is missing" do
      params = required_params.except(:effective_date)
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure).to include("effective date missing")
    end

    it "should fail when effective_date is not a Date" do
      params = required_params.merge(effective_date: "not-a-date")
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure).to include("effective date missing")
    end

    it "should fail when subject is missing" do
      params = required_params.except(:subject)
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure.join).to match(/subject missing/)
    end

    it "should fail when current_user is missing" do
      params = required_params.except(:current_user)
      result = subject.call(params)

      expect(result).to be_failure
      expect(result.failure.join).to match(/current_user is missing/)
    end
  end

  context "full end-to-end flow" do
    let(:evidence_value) { "true" }

    it "should persist eligibility to database" do
      expect do
        subject.call(required_params)
      end.to change { pvp.reload.eligibilities.count }.by(1)
    end

    it "should create eligibility with all required components" do
      result = subject.call(required_params)
      expect(result).to be_success

      eligibility = result.success

      # Verify eligibility structure
      expect(eligibility.key).to eq(:cca_shop_pvp_eligibility)
      expect(eligibility.title).to be_present
      expect(eligibility.current_state).to be_present
      expect(eligibility.state_histories).not_to be_empty

      # Verify evidences
      expect(eligibility.evidences).not_to be_empty
      evidence = eligibility.evidences.last
      expect(evidence.key).to eq(:shop_pvp_evidence)
      expect(evidence.is_satisfied).to be_truthy
      expect(evidence.state_histories).not_to be_empty

      # Verify grants are present
      expect(eligibility.grants).not_to be_empty
    end

    it "should reload eligibility from database correctly" do
      result = subject.call(required_params)
      expect(result).to be_success

      eligibility = result.success
      reloaded_eligibility = pvp.reload.eligibilities.by_key(:cca_shop_pvp_eligibility).max_by(&:created_at)

      expect(reloaded_eligibility.id).to eq(eligibility.id)
      expect(reloaded_eligibility.current_state).to eq(eligibility.current_state)
      expect(reloaded_eligibility.evidences.count).to eq(eligibility.evidences.count)
      expect(reloaded_eligibility.grants.count).to eq(eligibility.grants.count)
    end

    it "should handle state transitions correctly" do
      # Create with true value (eligible)
      result1 = subject.call(required_params)
      eligibility1 = result1.success
      expect(eligibility1.current_state).to eq(:eligible)

      # Update with false value (ineligible)
      result2 = subject.call(required_params.merge(evidence_value: "false"))
      eligibility2 = result2.success
      expect(eligibility2.current_state).to eq(:ineligible)

      # Verify state history tracks transitions
      expect(eligibility2.state_histories.map(&:to_state)).to include(:eligible, :ineligible)
    end
  end
end