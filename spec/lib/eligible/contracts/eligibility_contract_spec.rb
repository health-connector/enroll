# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::EligibilityContract do
  let(:contract) { described_class.new }

  let(:state_history_params) do
    {
      effective_on: Date.today,
      is_eligible: true,
      from_state: :initial,
      to_state: :eligible,
      transition_at: DateTime.now,
      event: :move_to_eligible
    }
  end

  let(:evidence_params) do
    {
      key: :shop_osse_evidence,
      title: "OSSE Evidence",
      is_satisfied: true,
      current_state: :approved,
      description: "Evidence for OSSE eligibility",
      state_histories: [state_history_params]
    }
  end

  let(:grant_params) do
    {
      title: "PVP Grant",
      key: :pvp_grant,
      value: { title: "PVP", key: "pvp" },
      state_histories: [state_history_params]
    }
  end

  context "with valid params" do
    let(:params) do
      {
        key: :cca_shop_pvp_eligibility,
        title: "PVP Eligibility",
        description: "Premium Value Product eligibility",
        subject: "BenefitMarkets::PremiumValueProduct",
        effective_date: Date.today,
        evidences: [evidence_params],
        grants: [grant_params],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [state_history_params]
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with Entity objects" do
    let(:params) do
      {
        key: :cca_shop_pvp_eligibility,
        title: "PVP Eligibility",
        description: "Test",
        subject: "BenefitMarkets::PremiumValueProduct",
        effective_date: Date.today,
        evidences: [Eligible::Entities::Evidence.new(evidence_params.merge(key: "shop_osse_evidence"))],
        grants: [
          Eligible::Entities::Grant.new(
            grant_params.merge(
              key: "pvp_grant",
              value: Eligible::Entities::Value.new(title: "PVP", key: "pvp")
            )
          )
        ],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
      }
    end

    it "accepts Entity objects directly" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with multiple evidences and grants" do
    let(:params) do
      {
        key: :cca_shop_pvp_eligibility,
        title: "PVP Eligibility",
        description: "Test",
        subject: "BenefitMarkets::PremiumValueProduct",
        effective_date: Date.today,
        evidences: [
          evidence_params,
          evidence_params.merge(key: :additional_evidence)
        ],
        grants: [
          grant_params,
          grant_params.merge(key: :additional_grant)
        ],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [state_history_params]
      }
    end

    it "validates multiple evidences and grants" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:evidences].size).to eq(2)
      expect(result.to_h[:grants].size).to eq(2)
    end
  end

  context "with symbol conversion" do
    let(:params) do
      {
        key: :test_eligibility,
        title: "Test",
        description: "Test",
        subject: "Test::Subject",
        effective_date: Date.today,
        evidences: [evidence_params],
        grants: [grant_params],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [state_history_params]
      }
    end

    it "converts symbols to strings" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:key]).to eq("test_eligibility")
      expect(result.to_h[:current_state]).to eq(:eligible)
    end
  end

  context "with missing required params" do
    it "fails when evidences is missing" do
      result = contract.call(
        key: :test,
        title: "Test",
        description: "Test",
        subject: "Test",
        effective_date: Date.today,
        grants: [grant_params],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [state_history_params]
      )
      expect(result).to be_failure
    end

    it "fails when grants is missing" do
      result = contract.call(
        key: :test,
        title: "Test",
        description: "Test",
        subject: "Test",
        effective_date: Date.today,
        evidences: [evidence_params],
        current_state: :eligible,
        is_eligible: true,
        state_histories: [state_history_params]
      )
      expect(result).to be_failure
    end
  end
end
