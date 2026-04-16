# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::TimeStamp do
  let(:submitted_at) { DateTime.now }
  let(:required_params) do
    {
      submitted_at: submitted_at
    }
  end

  let(:optional_params) do
    {
      created_at: DateTime.now,
      modified_at: DateTime.now
    }
  end

  context "with required params only" do
    it "creates a valid TimeStamp entity" do
      entity = described_class.new(required_params)

      expect(entity).to be_a(described_class)
      expect(entity.submitted_at).to eq(submitted_at)
      expect(entity.created_at).to be_nil
      expect(entity.modified_at).to be_nil
    end
  end

  context "with all params" do
    it "creates a valid TimeStamp entity" do
      params = required_params.merge(optional_params)
      entity = described_class.new(params)

      expect(entity).to be_a(described_class)
      expect(entity.submitted_at).to eq(submitted_at)
      expect(entity.created_at).to eq(optional_params[:created_at])
      expect(entity.modified_at).to eq(optional_params[:modified_at])
    end
  end

  context "with missing required params" do
    it "raises an error" do
      expect { described_class.new({}) }.to raise_error(Dry::Struct::Error)
    end
  end
end
