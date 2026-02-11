# frozen_string_literal: true

require 'rails_helper'

module BenefitSponsors
  module Services
    RSpec.describe PlanComparisonCostCalculator, type: :model, dbclean: :after_each do
      let!(:benefit_markets_location_rating_area) { FactoryBot.create_default(:benefit_markets_locations_rating_area) }
      let!(:benefit_markets_location_service_area) { FactoryBot.create_default(:benefit_markets_locations_service_area) }
      let(:current_effective_date) { TimeKeeper.date_of_record }
      let(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:benefit_market) { site.benefit_markets.first }
      let!(:issuer_profile) { FactoryBot.create(:benefit_sponsors_organizations_issuer_profile, assigned_site: site) }

      let!(:benefit_market_catalog) do
        create(
          :benefit_markets_benefit_market_catalog,
          :with_product_packages,
          benefit_market: benefit_market,
          issuer_profile: issuer_profile,
          title: "SHOP Benefits for #{current_effective_date.year}",
          application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
        )
      end

      let(:organization) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:employer_profile) { organization.employer_profile }
      let(:benefit_sponsorship) do
        sponsorship = employer_profile.add_benefit_sponsorship
        sponsorship.save
        sponsorship
      end

      let(:benefit_application) do
        application = FactoryBot.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship)
        application.benefit_sponsor_catalog.save!
        application
      end

      let(:product_package) { benefit_market_catalog.product_packages.where(package_kind: :single_issuer).first }
      let(:products) { product_package.products.take(3) }

      let(:form_params) do
        ActionController::Parameters.new(
          benefit_application_id: benefit_application.id.to_s,
          sponsored_benefits_attributes: {
            '0' => {
              kind: :health,
              reference_plan_id: products.first.id.to_s,
              product_package_kind: 'single_issuer',
              sponsor_contribution_attributes: {
                contribution_levels_attributes: {
                  '0' => {
                    contribution_factor: 0.75,
                    is_offered: true,
                    display_name: 'Employee Only',
                    contribution_unit_id: 'employee_only'
                  }
                }
              }
            }
          }
        ).permit!
      end

      let(:qhps) do
        products.map do |product|
          double(
            'QhpCostShareVariance',
            product: product,
            hios_plan_and_variant_id: product.hios_id,
            plan_marketing_name: "#{product.title} Plan"
          )
        end
      end

      subject { described_class.new(benefit_application, form_params) }

      describe '#initialize' do
        it 'sets the benefit_application' do
          expect(subject.benefit_application).to eq(benefit_application)
        end

        it 'sets the form_params' do
          expect(subject.form_params).to eq(form_params)
        end
      end

      describe '#calculate_for_plans' do
        context 'with valid parameters' do
          let(:census_employee) { FactoryBot.create(:census_employee, employer_profile: employer_profile) }

          before do
            allow(benefit_application.benefit_sponsorship).to receive(:census_employees).and_return([census_employee])
          end

          it 'returns a hash of costs keyed by product id' do
            result = subject.calculate_for_plans(qhps)
            expect(result).to be_a(Hash)
            expect(result.keys.size).to eq(3)
          end

          it 'calculates costs for each plan' do
            result = subject.calculate_for_plans(qhps)
            result.values.each do |cost|
              expect(cost).to be_a(Numeric)
              expect(cost).to be >= 0
            end
          end

          it 'uses the correct product for each calculation' do
            result = subject.calculate_for_plans(qhps)
            products.each do |product|
              expect(result).to have_key(product.id)
            end
          end
        end

        context 'with nil qhps' do
          it 'returns an empty hash' do
            result = subject.calculate_for_plans(nil)
            expect(result).to eq({})
          end
        end

        context 'with empty qhps array' do
          it 'returns an empty hash' do
            result = subject.calculate_for_plans([])
            expect(result).to eq({})
          end
        end

        context 'with nil form_params' do
          subject { described_class.new(benefit_application, nil) }

          it 'returns an empty hash' do
            result = subject.calculate_for_plans(qhps)
            expect(result).to eq({})
          end
        end

        context 'when an error occurs' do
          before do
            allow(subject).to receive(:build_benefit_package).and_raise(StandardError, "Test error")
          end

          it 'logs the error and returns empty hash' do
            expect(Rails.logger).to receive(:error).at_least(:once)
            result = subject.calculate_for_plans(qhps)
            expect(result).to eq({})
          end
        end
      end

      describe '#build_benefit_package' do
        it 'builds a benefit package using the factory' do
          benefit_package = subject.send(:build_benefit_package)
          expect(benefit_package).to be_a(BenefitSponsors::BenefitPackages::BenefitPackage)
        end

        it 'creates a sponsored benefit' do
          benefit_package = subject.send(:build_benefit_package)
          expect(benefit_package.sponsored_benefits).not_to be_empty
        end

        it 'sets the reference product' do
          benefit_package = subject.send(:build_benefit_package)
          sponsored_benefit = benefit_package.sponsored_benefits.first
          expect(sponsored_benefit.reference_product).to be_present
        end

        context 'with invalid form params' do
          subject { described_class.new(benefit_application, {}) }

          it 'returns nil' do
            result = subject.send(:build_benefit_package)
            expect(result).to be_nil
          end
        end
      end

      describe '#calculate_cost_for_plan' do
        let(:benefit_package) { subject.send(:build_benefit_package) }
        let(:sponsored_benefit) { benefit_package.sponsored_benefits.first }
        let(:product) { products.first }

        before do
          allow(benefit_application.benefit_sponsorship).to receive(:census_employees).and_return([])
        end

        it 'returns a numeric cost' do
          cost = subject.send(:calculate_cost_for_plan, product, sponsored_benefit, product_package)
          expect(cost).to be_a(Numeric)
        end

        it 'updates the reference product on the sponsored benefit' do
          subject.send(:calculate_cost_for_plan, product, sponsored_benefit, product_package)
          expect(sponsored_benefit.reference_product).to eq(product)
        end

        it 'returns 0.00 on error' do
          allow_any_instance_of(BenefitSponsors::SponsoredBenefits::CensusEmployeeCoverageCostEstimator)
            .to receive(:calculate).and_raise(StandardError, "Test error")

          cost = subject.send(:calculate_cost_for_plan, product, sponsored_benefit, product_package)
          expect(cost).to eq(0.00)
        end

        it 'rounds the cost to 2 decimal places' do
          allow_any_instance_of(BenefitSponsors::SponsoredBenefits::CensusEmployeeCoverageCostEstimator)
            .to receive(:calculate).and_return([nil, nil, 123.456])

          cost = subject.send(:calculate_cost_for_plan, product, sponsored_benefit, product_package)
          expect(cost).to eq(123.46)
        end
      end

      describe 'error handling' do
        it 'logs errors with backtrace' do
          exception = StandardError.new("Test error")
          allow(exception).to receive(:backtrace).and_return(['line 1', 'line 2'])

          expect(Rails.logger).to receive(:error).with("Test message: Test error")
          expect(Rails.logger).to receive(:error).with("line 1\nline 2")

          subject.send(:log_error, "Test message", exception)
        end
      end
    end
  end
end
