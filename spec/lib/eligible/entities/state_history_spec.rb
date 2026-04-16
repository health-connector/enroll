# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::StateHistory do
  let(:required_params) do
    {
      effective_on: Date.today,
      is_eligible: true,
      from_state: :initial,
      to_state: :approved,
      transition_at: DateTime.now,
      event: :move_to_approved
    }
  end

  let(:optional_params) do
    {
      reason: "Approved by admin",
      comment: "All requirements met",
      updated_by: "admin@example.com"
    }
  end

  context "with required params only" do
    it "creates a valid StateHistory entity" do
      entity = described_class.new(required_params)

      expect(entity).to be_a(described_class)
      expect(entity.effective_on).to eq(Date.today)
      expect(entity.is_eligible).to eq(true)
      expect(entity.from_state).to eq(:initial)
      expect(entity.to_state).to eq(:approved)
      expect(entity.event).to eq(:move_to_approved)
    end
  end

  context "with all params" do
    it "creates a valid StateHistory entity with optional fields" do
      params = required_params.merge(optional_params)
      entity = described_class.new(params)

      expect(entity.reason).to eq("Approved by admin")
      expect(entity.comment).to eq("All requirements met")
      expect(entity.updated_by).to eq("admin@example.com")
    end
  end

  context "with timestamps" do
    let(:timestamp_params) do
      {
        timestamps: Eligible::Entities::TimeStamp.new(submitted_at: DateTime.now)
      }
    end

    it "accepts TimeStamp entity" do
      params = required_params.merge(timestamp_params)
      entity = described_class.new(params)

      expect(entity.timestamps).to be_a(Eligible::Entities::TimeStamp)
    end
  end

  context "state transition map" do
    it "defines valid state transitions in Evidence" do
      # STATE_TRANSITION_MAP is defined in Evidence entity, not StateHistory
      expect(Eligible::Entities::Evidence::STATE_TRANSITION_MAP).to be_a(Hash)
      expect(Eligible::Entities::Evidence::STATE_TRANSITION_MAP[:approved]).to include(:initial)
    end
  end

  context "with symbol states" do
    it "accepts symbol values for states" do
      params = required_params.merge(
        from_state: :initial,
        to_state: :approved,
        event: :move_to_approved
      )
      entity = described_class.new(params)

      expect(entity.from_state).to eq(:initial)
      expect(entity.to_state).to eq(:approved)
      expect(entity.event).to eq(:move_to_approved)
    end
  end
end
