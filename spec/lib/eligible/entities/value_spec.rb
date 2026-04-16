# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::Value do
  let(:required_params) do
    {
      title: "Premium Value Product",
      key: "pvp_eligibility"
    }
  end

  context "with valid params" do
    it "creates a valid Value entity" do
      entity = described_class.new(required_params)

      expect(entity).to be_a(described_class)
      expect(entity.title).to eq("Premium Value Product")
      expect(entity.key).to eq("pvp_eligibility")
    end
  end

  context "with string key" do
    it "accepts string key" do
      params = required_params.merge(key: "pvp_eligibility")
      entity = described_class.new(params)

      expect(entity.key).to eq("pvp_eligibility")
    end
  end

  context "with missing required params" do
    it "raises an error when title is missing" do
      expect { described_class.new(key: :test) }.to raise_error(Dry::Struct::Error)
    end

    it "raises an error when key is missing" do
      expect { described_class.new(title: "Test") }.to raise_error(Dry::Struct::Error)
    end
  end
end
