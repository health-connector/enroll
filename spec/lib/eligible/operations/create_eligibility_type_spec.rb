# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Operations::CreateEligibilityType do
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
      key: "shop_osse_evidence",
      title: "OSSE Evidence",
      is_satisfied: true,
      current_state: "approved",
      description: "Evidence for OSSE eligibility",
      state_histories: [state_history_params]
    }
  end

  let(:grant_params) do
    {
      title: "PVP Grant",
      key: "pvp_grant",
      value: { title: "PVP", key: "pvp" },
      state_histories: [state_history_params]
    }
  end

  let(:eligibility_params) do
    {
      key: "cca_shop_pvp_eligibility",
      title: "PVP Eligibility",
      description: "Premium Value Product eligibility",
      subject: "BenefitMarkets::PremiumValueProduct",
      effective_date: Date.today,
      evidences: [evidence_params],
      grants: [grant_params],
      current_state: "eligible",
      is_eligible: true,
      state_histories: [state_history_params]
    }
  end

  let(:params) do
    {
      subject: Eligible::Entities::Eligibility,
      eligibility: eligibility_params
    }
  end

  context "with valid params" do
    it "creates an eligibility entity successfully" do
      result = described_class.new.call(params)

      expect(result).to be_success
      expect(result.success).to be_a(Eligible::Entities::Eligibility)
    end

    it "returns an eligibility with correct attributes" do
      eligibility = described_class.new.call(params).success

      # Entities use string keys
      expect(eligibility.key).to eq("cca_shop_pvp_eligibility")
      expect(eligibility.current_state).to eq(:eligible)
      expect(eligibility.evidences.size).to eq(1)
      expect(eligibility.grants.size).to eq(1)
    end
  end

  context "with invalid state transition" do
    let(:invalid_history) do
      state_history_params.merge(from_state: :eligible, to_state: :initial)
    end

    let(:invalid_params) do
      params.merge(
        eligibility: eligibility_params.merge(state_histories: [invalid_history])
      )
    end

    it "fails validation" do
      result = described_class.new.call(invalid_params)
      expect(result).to be_failure
      expect(result.failure).to include(match(/invalid transition/))
    end
  end

  context "with invalid event" do
    let(:invalid_history) do
      state_history_params.merge(event: :invalid_event)
    end

    let(:invalid_params) do
      params.merge(
        eligibility: eligibility_params.merge(state_histories: [invalid_history])
      )
    end

    it "fails validation" do
      result = described_class.new.call(invalid_params)
      expect(result).to be_failure
      expect(result.failure).to include(match(/invalid event/))
    end
  end

  context "with contract validation failure" do
    let(:invalid_params) do
      params.merge(
        eligibility: eligibility_params.except(:evidences)
      )
    end

    it "returns contract errors" do
      result = described_class.new.call(invalid_params)
      expect(result).to be_failure
    end
  end
end
