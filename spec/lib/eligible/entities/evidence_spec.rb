# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::Evidence do
  let(:state_history_params) do
    {
      effective_on: Date.today,
      is_eligible: true,
      from_state: :initial,
      to_state: :approved,
      transition_at: DateTime.now,
      event: :move_to_approved
    }
  end

  let(:required_params) do
    {
      key: "shop_osse_evidence",
      title: "OSSE Evidence",
      is_satisfied: true,
      current_state: :approved,
      description: "Evidence for OSSE eligibility",
      state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
    }
  end

  context "with valid params" do
    it "creates a valid Evidence entity" do
      entity = described_class.new(required_params)

      expect(entity).to be_a(described_class)
      expect(entity.key).to eq("shop_osse_evidence")
      expect(entity.title).to eq("OSSE Evidence")
      expect(entity.is_satisfied).to eq(true)
      expect(entity.current_state).to eq(:approved)
      expect(entity.description).to eq("Evidence for OSSE eligibility")
      expect(entity.state_histories.first).to be_a(Eligible::Entities::StateHistory)
    end
  end

  context "with multiple state histories" do
    it "tracks state progression" do
      histories = [
        Eligible::Entities::StateHistory.new(state_history_params),
        Eligible::Entities::StateHistory.new(
          state_history_params.merge(
            from_state: :approved,
            to_state: :denied,
            event: :move_to_denied,
            is_eligible: false
          )
        )
      ]

      params = required_params.merge(state_histories: histories)
      entity = described_class.new(params)

      expect(entity.state_histories.size).to eq(2)
      expect(entity.state_histories.last.to_state).to eq(:denied)
    end
  end

  context "with unsatisfied evidence" do
    it "creates evidence with is_satisfied false" do
      params = required_params.merge(
        is_satisfied: false,
        current_state: :denied
      )

      entity = described_class.new(params)
      expect(entity.is_satisfied).to eq(false)
      expect(entity.current_state).to eq(:denied)
    end
  end

  context "state transition map" do
    it "defines valid state transitions" do
      expect(described_class::STATE_TRANSITION_MAP).to be_a(Hash)
      expect(described_class::STATE_TRANSITION_MAP[:approved]).to include(:initial)
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
