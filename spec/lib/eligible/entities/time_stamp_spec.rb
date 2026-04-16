# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Entities::TimeStamp do
  let(:created_at) { DateTime.now }
  let(:basic_params) do
    {
      created_at: created_at
    }
  end

  let(:all_params) do
    {
      created_at: DateTime.now,
      modified_at: DateTime.now
    }
  end

  context "with required params only" do
    it "creates a valid TimeStamp entity" do
      entity = described_class.new(basic_params)

      expect(entity).to be_a(described_class)
      expect(entity.created_at).to eq(created_at)
      expect(entity.modified_at).to be_nil
    end
  end

  context "with all params" do
    it "creates a valid TimeStamp entity" do
      entity = described_class.new(all_params)

      expect(entity).to be_a(described_class)
      expect(entity.created_at).to eq(all_params[:created_at])
      expect(entity.modified_at).to eq(all_params[:modified_at])
    end
  end

  context "with missing required params" do
    it "allows empty params since all fields are optional" do
      expect { described_class.new({}) }.not_to raise_error
    end
  end
end
