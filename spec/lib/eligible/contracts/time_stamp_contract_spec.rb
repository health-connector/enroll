# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::TimeStampContract do
  let(:contract) { described_class.new }

  context "with valid params" do
    let(:params) do
      {
        submitted_at: DateTime.now
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with all optional params" do
    let(:params) do
      {
        submitted_at: DateTime.now,
        created_at: DateTime.now,
        modified_at: DateTime.now
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h).to include(:submitted_at, :created_at, :modified_at)
    end
  end

  context "with missing required params" do
    it "fails validation" do
      result = contract.call({})
      expect(result).to be_failure
      expect(result.errors.to_h).to have_key(:submitted_at)
    end
  end
end
