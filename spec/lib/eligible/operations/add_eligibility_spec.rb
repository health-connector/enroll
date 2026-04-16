# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Operations::AddEligibility do
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

  context "with valid params" do
    let(:params) do
      {
        subject: "Eligible::Entities::Eligibility",
        eligibility: eligibility_params
      }
    end

    it "creates an eligibility successfully" do
      result = described_class.new.call(params)

      expect(result).to be_success
      expect(result.success).to be_a(Eligible::Entities::Eligibility)
    end

    it "returns correct eligibility attributes" do
      eligibility = described_class.new.call(params).success

      # Entities use string keys
      expect(eligibility.key).to eq("cca_shop_pvp_eligibility")
      expect(eligibility.title).to eq("PVP Eligibility")
      expect(eligibility.evidences).to be_an(Array)
      expect(eligibility.grants).to be_an(Array)
    end
  end

  context "with missing subject" do
    let(:params) do
      {
        eligibility: eligibility_params
      }
    end

    it "fails with subject required error" do
      result = described_class.new.call(params)

      expect(result).to be_failure
      expect(result.failure).to eq("subject is required")
    end
  end

  context "with missing eligibility" do
    let(:params) do
      {
        subject: "Eligible::Entities::Eligibility"
      }
    end

    it "fails with eligibility required error" do
      result = described_class.new.call(params)

      expect(result).to be_failure
      expect(result.failure).to eq("eligibility is required")
    end
  end

  context "with invalid subject class" do
    let(:params) do
      {
        subject: "NonExistentClass",
        eligibility: eligibility_params
      }
    end

    it "returns failure for invalid subject class" do
      result = described_class.new.call(params)
      
      expect(result).to be_failure
      expect(result.failure).to include("Invalid subject type")
    end
  end

  context "integration with CreateEligibilityType" do
    let(:params) do
      {
        subject: "Eligible::Entities::Eligibility",
        eligibility: eligibility_params
      }
    end

    it "calls CreateEligibilityType successfully" do
      result = described_class.new.call(params)

      expect(result).to be_success
      expect(result.success).to be_a(Eligible::Entities::Eligibility)
    end
  end
end
