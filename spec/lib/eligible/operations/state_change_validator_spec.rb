# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Operations::StateChangeValidator do
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

  context "with Evidence resource" do
    let(:validator) { described_class.new([state_history_params], Eligible::Entities::Evidence) }

    it "validates successfully" do
      validator.validate
      expect(validator.errors).to be_empty
    end

    context "with invalid event" do
      let(:invalid_params) do
        state_history_params.merge(event: :invalid_event)
      end

      it "registers an error" do
        validator = described_class.new([invalid_params], Eligible::Entities::Evidence)
        validator.validate
        expect(validator.errors).to include(match(/invalid event/))
      end
    end

    context "with invalid transition" do
      let(:invalid_params) do
        state_history_params.merge(from_state: :approved, to_state: :initial)
      end

      it "registers a transition error" do
        validator = described_class.new([invalid_params], Eligible::Entities::Evidence)
        validator.validate
        expect(validator.errors).to include(match(/invalid transition/))
      end
    end

    context "with is_eligible mismatch" do
      let(:invalid_params) do
        state_history_params.merge(to_state: :approved, is_eligible: false)
      end

      it "registers is_eligible error" do
        validator = described_class.new([invalid_params], Eligible::Entities::Evidence)
        validator.validate
        expect(validator.errors).to include(match(/is_eligible must be true/))
      end
    end
  end

  context "with Eligibility resource" do
    let(:eligibility_history) do
      state_history_params.merge(
        to_state: :eligible,
        event: :move_to_eligible
      )
    end

    let(:validator) do
      described_class.new(
        [eligibility_history],
        Eligible::Entities::Eligibility
      )
    end

    it "validates successfully" do
      validator.validate
      expect(validator.errors).to be_empty
    end
  end

  context "with multiple state histories" do
    let(:first_history) do
      {
        effective_on: Date.today - 1,
        is_eligible: true,
        from_state: :initial,
        to_state: :approved,
        transition_at: DateTime.now - 1,
        event: :move_to_approved
      }
    end

    let(:second_history) do
      {
        effective_on: Date.today,
        is_eligible: false,
        from_state: :approved,
        to_state: :denied,
        transition_at: DateTime.now,
        event: :move_to_denied
      }
    end

    it "validates state progression" do
      validator = described_class.new(
        [first_history, second_history],
        Eligible::Entities::Evidence
      )
      validator.validate
      expect(validator.errors).to be_empty
    end

    context "with mismatched state progression" do
      let(:invalid_second) do
        second_history.merge(from_state: :initial)
      end

      it "detects state mismatch" do
        validator = described_class.new(
          [first_history, invalid_second],
          Eligible::Entities::Evidence
        )
        validator.validate
        expect(validator.errors).to include(match(/state mismatch/))
      end
    end
  end
end
