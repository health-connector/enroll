# frozen_string_literal: true

require "rails_helper"

RSpec.describe Eligible::Types do
  it "includes Dry.Types" do
    expect(described_class.ancestors).to include(Dry::Types::Module)
  end

  it "provides standard types" do
    expect(described_class::String).to respond_to(:call)
    expect(described_class::Symbol).to respond_to(:call)
    expect(described_class::Bool).to respond_to(:call)
    expect(described_class::Array).to respond_to(:call)
    expect(described_class::Hash).to respond_to(:call)
  end
end
