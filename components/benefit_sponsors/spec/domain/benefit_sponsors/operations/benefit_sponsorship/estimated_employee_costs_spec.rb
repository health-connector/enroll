# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_site_spec_helpers.rb"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_product_spec_helpers.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"

RSpec.describe BenefitSponsors::Operations::BenefitSponsorship::EstimatedEmployeeCosts, dbclean: :after_each do

  describe "#EstimatedEmployeeCosts" do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"
    include_context "setup employees with benefits"

    let(:sponsored_benefit) { current_benefit_package.sponsored_benefits.first }
    let(:reference_product) { sponsored_benefit.reference_product }

    let(:params) do
      {
        benefit_application: initial_application,
        benefit_package: current_benefit_package
      }
    end

    before :each do
      allow(reference_product).to receive(:carrier_profile_hios_ids).and_return([reference_product.hios_id.slice(0..4)])
      ::BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
      @result = subject.call(params)
    end

    it 'should return success' do
      expect(@result.success?).to be_truthy
    end

    it 'should return employee estimated costs' do
      expect(@result.value!.size).to eq 3
    end

    it "should return all needed estimated costs keys" do
      expect(@result.value!.keys).to include([:employee_costs, :employer_estimated_costs, :reference_product])
    end
  end
end

