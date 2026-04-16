# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::GrantContract do
  let(:contract) { described_class.new }

  let(:value_params) do
    {
      title: "PVP Grant",
      key: "pvp_grant"
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

  context "with valid params" do
    let(:params) do
      {
        title: "PVP Eligibility Grant",
        key: "pvp_eligibility_grant",
        value: value_params,
        state_histories: [state_history_params]
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with Value hash" do
    let(:params) do
      {
        title: "Test Grant",
        key: "test_grant",
        value: value_params,
        state_histories: [state_history_params]
      }
    end

    it "accepts Value hash directly" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with StateHistory entity" do
    let(:params) do
      {
        title: "Test Grant",
        key: "test_grant",
        value: value_params,
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
        title: "Test Grant",
        key: "test_grant",
        value: value_params,
        state_histories: [
          state_history_params,
          state_history_params.merge(from_state: :approved, to_state: :denied)
        ]
      }
    end

    it "validates multiple state histories" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:state_histories].size).to eq(2)
    end
  end

  context "with symbol keys" do
    let(:params) do
      {
        title: "Test Grant",
        key: "test_grant",
        value: value_params,
        state_histories: [state_history_params]
      }
    end

    it "accepts string keys" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:key]).to eq("test_grant")
    end
  end

  context "with missing required params" do
    it "fails when value is missing" do
      result = contract.call(
        title: "Test",
        key: "test",
        state_histories: [state_history_params]
      )
      expect(result).to be_failure
    end

    it "fails when state_histories is missing" do
      result = contract.call(
        title: "Test",
        key: :test,
        value: value_params
      )
      expect(result).to be_failure
    end
  end
end
