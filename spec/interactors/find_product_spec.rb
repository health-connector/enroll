# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"

describe FindProduct, :dbclean => :after_each do
  # product shopping is done and nothing to shop for
  context "when nil params are passed" do
    it "should not fetch product and return failure" do
      context = described_class.call(params: {product_id: nil})
      expect(context.failure?).to be_truthy
      expect(context.product).to eq nil
    end
  end

  context "when invalid params are passed" do
    it "should not fetch product and return failure" do
      context = described_class.call(params: {product_id: "234532"})
      expect(context.failure?).to be_truthy
      expect(context.product).to eq nil
    end
  end

  # product shopping is not done and shopping for health/dental
  context "when valid params are passed" do
    include_context "setup benefit market with market catalogs and product packages"

    it "should fetch product" do
      context = described_class.call(params: {product_id: health_products.first.id})
      expect(context.success?).to be_truthy
      expect(context.product.present?).to be_truthy
    end
  end
end
