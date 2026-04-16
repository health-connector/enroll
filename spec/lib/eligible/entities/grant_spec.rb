# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::Grant do
  let(:value_params) do
    {
      title: "PVP Grant",
      key: :pvp_grant
    }
  end

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
      title: "PVP Eligibility Grant",
      key: :pvp_eligibility_grant,
      value: Eligible::Entities::Value.new(value_params),
      state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
    }
  end

  context "with valid params" do
    it "creates a valid Grant entity" do
      entity = described_class.new(required_params)
      
      expect(entity).to be_a(described_class)
      expect(entity.title).to eq("PVP Eligibility Grant")
      expect(entity.key).to eq(:pvp_eligibility_grant)
      expect(entity.value).to be_a(Eligible::Entities::Value)
      expect(entity.state_histories).to be_an(Array)
      expect(entity.state_histories.first).to be_a(Eligible::Entities::StateHistory)
    end
  end

  context "with multiple state histories" do
    it "accepts multiple state history entries" do
      second_history = state_history_params.merge(
        from_state: :approved,
        to_state: :denied,
        event: :move_to_denied,
        is_eligible: false
      )
      
      params = required_params.merge(
        state_histories: [
          Eligible::Entities::StateHistory.new(state_history_params),
          Eligible::Entities::StateHistory.new(second_history)
        ]
      )
      
      entity = described_class.new(params)
      expect(entity.state_histories.size).to eq(2)
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

  context "with missing required params" do
    it "raises an error when value is missing" do
      invalid_params = required_params.except(:value)
      expect { described_class.new(invalid_params) }.to raise_error(Dry::Struct::Error)
    end

    it "raises an error when state_histories is missing" do
      invalid_params = required_params.except(:state_histories)
      expect { described_class.new(invalid_params) }.to raise_error(Dry::Struct::Error)
    end
  end
end
