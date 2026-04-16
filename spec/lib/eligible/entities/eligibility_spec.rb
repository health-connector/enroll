# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::Eligibility do
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
      current_state: :approved,
      description: "Evidence for OSSE eligibility",
      state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
    }
  end

  let(:grant_params) do
    {
      title: "PVP Grant",
      key: "pvp_grant",
      value: Eligible::Entities::Value.new(title: "PVP", key: "pvp"),
      state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
    }
  end

  let(:required_params) do
    {
      key: "cca_shop_pvp_eligibility",
      title: "PVP Eligibility",
      description: "Premium Value Product eligibility",
      subject: "BenefitMarkets::PremiumValueProduct",
      effective_date: Date.today,
      evidences: [Eligible::Entities::Evidence.new(evidence_params)],
      grants: [Eligible::Entities::Grant.new(grant_params)],
      current_state: :eligible,
      is_eligible: true,
      state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
    }
  end

  context "with valid params" do
    it "creates a valid Eligibility entity" do
      entity = described_class.new(required_params)

      expect(entity).to be_a(described_class)
      expect(entity.key).to eq("cca_shop_pvp_eligibility")
      expect(entity.title).to eq("PVP Eligibility")
      expect(entity.current_state).to eq(:eligible)
      expect(entity.evidences.size).to eq(1)
      expect(entity.grants.size).to eq(1)
    end
  end

  context "with evidences and grants" do
    it "contains Evidence and Grant entities" do
      entity = described_class.new(required_params)

      expect(entity.evidences).to be_an(Array)
      expect(entity.evidences.first).to be_a(Eligible::Entities::Evidence)
      expect(entity.grants).to be_an(Array)
      expect(entity.grants.first).to be_a(Eligible::Entities::Grant)
    end
  end

  context "state constants" do
    it "defines eligible statuses" do
      expect(described_class::ELIGIBLE_STATUSES).to include(:eligible)
    end

    it "defines ineligible statuses" do
      expect(described_class::INELIGIBLE_STATUSES).to include(:initial, :ineligible)
    end

    it "defines events" do
      expect(described_class::EVENTS).to include(:move_to_eligible, :move_to_ineligible)
    end

    it "defines state transition map" do
      expect(described_class::STATE_TRANSITION_MAP).to be_a(Hash)
      expect(described_class::STATE_TRANSITION_MAP[:eligible]).to include(:initial)
      expect(described_class::STATE_TRANSITION_MAP[:ineligible]).to include(:eligible)
    end
  end

  context "with multiple evidences" do
    it "accepts multiple evidences" do
      second_evidence = evidence_params.merge(
        key: "additional_evidence",
        title: "Additional Evidence"
      )

      params = required_params.merge(
        evidences: [
          Eligible::Entities::Evidence.new(evidence_params),
          Eligible::Entities::Evidence.new(second_evidence)
        ]
      )

      entity = described_class.new(params)
      expect(entity.evidences.size).to eq(2)
    end
  end

  context "with ineligible state" do
    it "creates ineligible eligibility" do
      params = required_params.merge(
        is_eligible: false,
        current_state: :ineligible,
        state_histories: [
          Eligible::Entities::StateHistory.new(
            state_history_params.merge(
              is_eligible: false,
              to_state: :ineligible,
              event: :move_to_ineligible
            )
          )
        ]
      )

      entity = described_class.new(params)
      expect(entity.current_state).to eq(:ineligible)
    end
  end

  context "with timestamps" do
    it "accepts timestamps" do
      params = required_params.merge(
        timestamps: Eligible::Entities::TimeStamp.new(submitted_at: DateTime.now)
      )

      entity = described_class.new(params)
      expect(entity.timestamps).to be_a(Eligible::Entities::TimeStamp)
    end
  end
end
