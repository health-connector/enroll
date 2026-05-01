# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::ValueContract do
  let(:contract) { described_class.new }

  context "with valid params" do
    let(:params) do
      {
        title: "PVP Value",
        key: "pvp_value"
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
    end
  end

  context "with symbol key" do
    let(:params) do
      {
        title: "Test",
        key: :test_key
      }
    end

    it "fails validation for symbol key" do
      result = contract.call(params)
      expect(result).to be_failure
      expect(result.errors[:key]).to include("must be a string")
    end
  end

  context "with string key" do
    let(:params) do
      {
        title: "Test",
        key: "test_key"
      }
    end

    it "keeps string as is" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h[:key]).to eq("test_key")
    end
  end

  context "with missing required params" do
    it "fails when title is missing" do
      result = contract.call(key: :test)
      expect(result).to be_failure
      expect(result.errors.to_h).to have_key(:title)
    end

    it "fails when key is missing" do
      result = contract.call(title: "Test")
      expect(result).to be_failure
      expect(result.errors.to_h).to have_key(:key)
    end
  end
end
