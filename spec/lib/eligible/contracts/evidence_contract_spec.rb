# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::EvidenceContract do
  let(:contract) { described_class.new }

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

  context "with valid params" do
    let(:params) do
      {
        key: :shop_osse_evidence,
        title: "OSSE Evidence",
        is_satisfied: true,
        current_state: :approved,
        description: "Evidence for OSSE eligibility",
        state_histories: [state_history_params]
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with StateHistory entity" do
    let(:params) do
      {
        key: :shop_osse_evidence,
        title: "OSSE Evidence",
        is_satisfied: true,
        current_state: :approved,
        description: "Test description",
        state_histories: [Eligible::Entities::StateHistory.new(state_history_params)]
      }
    end

    it "accepts StateHistory entity directly" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with multiple state histories" do
    let(:params) do
      {
        key: :shop_osse_evidence,
        title: "OSSE Evidence",
        is_satisfied: false,
        current_state: :denied,
        description: "Test",
        state_histories: [
          state_history_params,
          state_history_params.merge(
            from_state: :approved,
            to_state: :denied,
            is_eligible: false
          )
        ]
      }
    end

    it "validates multiple state histories" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:state_histories].size).to eq(2)
    end
  end

  context "with symbol conversion" do
    let(:params) do
      {
        key: :test_evidence,
        title: "Test",
        is_satisfied: true,
        current_state: :approved,
        description: "Test",
        state_histories: [state_history_params]
      }
    end

    it "converts symbols to strings" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:key]).to eq("test_evidence")
      expect(result.to_h[:current_state]).to eq("approved")
    end
  end

  context "with missing required params" do
    it "fails when key is missing" do
      result = contract.call(
        title: "Test",
        is_satisfied: true,
        current_state: :approved,
        description: "Test",
        state_histories: [state_history_params]
      )
      expect(result).to be_failure
    end

    it "fails when state_histories is missing" do
      result = contract.call(
        key: :test,
        title: "Test",
        is_satisfied: true,
        current_state: :approved,
        description: "Test"
      )
      expect(result).to be_failure
    end
  end
end
