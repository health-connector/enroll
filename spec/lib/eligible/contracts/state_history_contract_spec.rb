# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::StateHistoryContract do
  let(:contract) { described_class.new }

  context "with valid params" do
    let(:params) do
      {
        effective_on: Date.today,
        is_eligible: true,
        from_state: :initial,
        to_state: :approved,
        transition_at: DateTime.now,
        event: :move_to_approved
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with symbol states" do
    let(:params) do
      {
        effective_on: Date.today,
        is_eligible: true,
        from_state: :initial,
        to_state: :approved,
        transition_at: DateTime.now,
        event: :move_to_approved
      }
    end

    it "converts symbols to strings" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:from_state]).to eq("initial")
      expect(result.to_h[:to_state]).to eq("approved")
      expect(result.to_h[:event]).to eq("move_to_approved")
    end
  end

  context "with optional params" do
    let(:params) do
      {
        effective_on: Date.today,
        is_eligible: true,
        from_state: :initial,
        to_state: :approved,
        transition_at: DateTime.now,
        event: :move_to_approved,
        reason: "Admin approval",
        comment: "All requirements met",
        updated_by: "admin@example.com"
      }
    end

    it "accepts optional fields" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h).to include(:reason, :comment, :updated_by)
    end
  end

  context "with missing required params" do
    it "fails when effective_on is missing" do
      result = contract.call(
        is_eligible: true,
        from_state: :initial,
        to_state: :approved,
        transition_at: DateTime.now,
        event: :move_to_approved
      )
      expect(result).to be_failure
    end
  end
end
