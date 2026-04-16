# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Contracts::TimeStampContract do
  let(:contract) { described_class.new }

  context "with valid params" do
    let(:params) do
      {
        created_at: DateTime.now
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
        created_at: DateTime.now,
        modified_at: DateTime.now
      }
    end

    it "passes validation" do
      result = contract.call(params)
      expect(result).to be_success
      expect(result.to_h).to include(:created_at, :modified_at)
    end
  end

  context "with missing required params" do
    it "passes validation since all fields are optional" do
      result = contract.call({})
      expect(result).to be_success
    end
  end
end
