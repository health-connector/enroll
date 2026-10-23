require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe SponsoredBenefits::SponsoredBenefit, type: :model, :dbclean => :after_each do
    describe '#elected_products' do
      include_context "setup benefit market with market catalogs and product packages"
      include_context "setup initial benefit application"

      let(:sponsored_benefit) { initial_application.benefit_packages.first.health_sponsored_benefit }
      let(:coverage_date) { initial_application.start_on.to_date }

      it 'returns the products offered on the coverage date' do
        expect(sponsored_benefit.elected_products(coverage_date)).to match_array(sponsored_benefit.products(coverage_date))
        expect(sponsored_benefit.elected_products(coverage_date)).not_to be_empty
      end

      context 'when no catalog product has a premium table for the coverage date' do
        before do
          catalog = initial_application.benefit_sponsor_catalog
          catalog.class.collection.update_one({ _id: catalog.id }, { '$set' => { 'product_packages.$[].products.$[].premium_tables' => [] } })
        end

        let(:sponsored_benefit) do
          BenefitSponsors::BenefitApplications::BenefitApplication.find(initial_application.id).benefit_packages.first.health_sponsored_benefit
        end

        it 'returns the package products for the plan option and service areas' do
          expect(sponsored_benefit.products(coverage_date)).to be_empty
          expect(sponsored_benefit.elected_products(coverage_date).map(&:issuer_profile_id).uniq).to eq([issuer_profile.id])
        end
      end

      context 'with a single product package' do
        let(:package_kind) { :single_product }

        it 'returns the reference product' do
          expect(sponsored_benefit.elected_products(coverage_date)).to eq([sponsored_benefit.reference_product])
        end
      end
    end
  end
end
