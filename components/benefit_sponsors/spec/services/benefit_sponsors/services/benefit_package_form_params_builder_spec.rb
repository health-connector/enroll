# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BenefitSponsors
  module Services
    RSpec.describe BenefitPackageFormParamsBuilder, type: :model, dbclean: :after_each do
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
      let(:product) { product_package.products.first }

      let(:base_params) do
        ActionController::Parameters.new(
          benefit_application_id: benefit_application.id.to_s,
          reference_plan_id: product.id.to_s,
          product_package_kind: 'single_issuer',
          contribution_levels: {
            '0' => {
              contribution_factor: '0.75',
              is_offered: 'true',
              display_name: 'Employee Only',
              contribution_unit_id: 'employee_only'
            },
            '1' => {
              contribution_factor: '0.50',
              is_offered: 'true',
              display_name: 'Employee + Spouse',
              contribution_unit_id: 'employee_and_spouse'
            }
          }
        )
      end

      subject { described_class.new(base_params) }

      describe '#initialize' do
        it 'sets the params' do
          expect(subject.params).to eq(base_params)
        end
      end

      describe '#build' do
        context 'with valid parameters' do
          it 'returns permitted parameters' do
            result = subject.build
            expect(result).to be_a(ActionController::Parameters)
            expect(result).to be_permitted
          end

          it 'includes benefit_application_id' do
            result = subject.build
            expect(result[:benefit_application_id]).to eq(benefit_application.id.to_s)
          end

          it 'includes sponsored_benefits_attributes' do
            result = subject.build
            expect(result[:sponsored_benefits_attributes]).to be_present
            expect(result[:sponsored_benefits_attributes]['0']).to be_present
          end

          it 'sets kind to health' do
            result = subject.build
            expect(result[:sponsored_benefits_attributes]['0'][:kind]).to eq(:health)
          end

          it 'includes reference_plan_id' do
            result = subject.build
            expect(result[:sponsored_benefits_attributes]['0'][:reference_plan_id]).to eq(product.id.to_s)
          end

          it 'includes sponsor_contribution_attributes' do
            result = subject.build
            contribution_attrs = result[:sponsored_benefits_attributes]['0'][:sponsor_contribution_attributes]
            expect(contribution_attrs).to be_present
            expect(contribution_attrs[:contribution_levels_attributes]).to be_present
          end

          it 'builds contribution levels correctly' do
            result = subject.build
            levels = result[:sponsored_benefits_attributes]['0'][:sponsor_contribution_attributes][:contribution_levels_attributes]

            expect(levels.keys.size).to eq(2)
            expect(levels['0'][:contribution_factor]).to eq('0.75')
            expect(levels['0'][:is_offered]).to eq('true')
            expect(levels['1'][:contribution_factor]).to eq('0.50')
          end
        end

        context 'with missing reference_plan_id' do
          let(:invalid_params) do
            ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              product_package_kind: 'single_issuer'
            )
          end

          subject { described_class.new(invalid_params) }

          it 'returns nil' do
            expect(subject.build).to be_nil
          end
        end

        context 'with missing benefit_application_id' do
          let(:invalid_params) do
            ActionController::Parameters.new(
              reference_plan_id: product.id.to_s,
              product_package_kind: 'single_issuer'
            )
          end

          subject { described_class.new(invalid_params) }

          it 'returns nil' do
            expect(subject.build).to be_nil
          end
        end

        context 'with existing benefit package' do
          let(:benefit_package) do
            FactoryBot.create(
              :benefit_sponsors_benefit_packages_benefit_package,
              benefit_application: benefit_application,
              product_package: product_package
            )
          end

          let(:params_with_package_id) do
            base_params.merge(benefit_package_id: benefit_package.id.to_s)
          end

          subject { described_class.new(params_with_package_id) }

          it 'includes the benefit package id' do
            result = subject.build
            expect(result[:id]).to eq(benefit_package.id.to_s)
          end

          it 'includes sponsored benefit id if it exists' do
            sponsored_benefit = benefit_package.sponsored_benefits.first
            if sponsored_benefit
              result = subject.build
              expect(result[:sponsored_benefits_attributes]['0'][:id]).to eq(sponsored_benefit.id)
            end
          end
        end

        context 'without contribution levels' do
          let(:params_without_contributions) do
            ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              reference_plan_id: product.id.to_s,
              product_package_kind: 'single_issuer'
            )
          end

          subject { described_class.new(params_without_contributions) }

          it 'does not include sponsor_contribution_attributes' do
            result = subject.build
            expect(result[:sponsored_benefits_attributes]['0'][:sponsor_contribution_attributes]).to be_nil
          end
        end
      end

      describe '#valid_params?' do
        it 'returns true with valid params' do
          expect(subject.send(:valid_params?)).to be true
        end

        context 'without reference_plan_id' do
          before do
            base_params.delete(:reference_plan_id)
          end

          it 'returns false' do
            expect(subject.send(:valid_params?)).to be false
          end
        end

        context 'without benefit_application_id' do
          before do
            base_params.delete(:benefit_application_id)
          end

          it 'returns false' do
            expect(subject.send(:valid_params?)).to be false
          end
        end
      end

      describe '#package_exists?' do
        context 'with a valid existing package' do
          let(:benefit_package) do
            FactoryBot.create(
              :benefit_sponsors_benefit_packages_benefit_package,
              benefit_application: benefit_application,
              product_package: product_package
            )
          end

          before do
            base_params[:benefit_package_id] = benefit_package.id.to_s
          end

          it 'returns true' do
            expect(subject.send(:package_exists?)).to be true
          end
        end

        context 'with no package_id' do
          it 'returns false' do
            expect(subject.send(:package_exists?)).to be false
          end
        end

        context 'with invalid package_id' do
          before do
            base_params[:benefit_package_id] = BSON::ObjectId.new.to_s
          end

          it 'returns false' do
            expect(subject.send(:package_exists?)).to be false
          end
        end
      end

      describe 'error handling' do
        context 'when benefit_application is not found' do
          before do
            base_params[:benefit_application_id] = BSON::ObjectId.new.to_s
          end

          it 'returns false' do
            expect(subject.send(:package_exists?)).to be false
          end
        end
      end

      describe 'dental benefit type support' do
        let(:dental_product_package) { benefit_market_catalog.product_packages.where(package_kind: :single_product, benefit_kind: :dental).first }
        let(:dental_product) { dental_product_package&.products&.first }

        let(:dental_params) do
          ActionController::Parameters.new(
            benefit_application_id: benefit_application.id.to_s,
            benefit_type: 'dental',
            reference_plan_id: dental_product&.id&.to_s || BSON::ObjectId.new.to_s,
            product_package_kind: 'single_product',
            product_option_choice: issuer_profile.id.to_s,
            contribution_levels: {
              '0' => {
                contribution_factor: '55',
                is_offered: '1',
                display_name: 'Employee',
                contribution_unit_id: 'employee_unit_id'
              }
            }
          )
        end

        let(:dental_builder) { described_class.new(dental_params) }

        context 'when building dental benefit params' do
          it 'sets kind to dental' do
            result = dental_builder.build
            expect(result[:sponsored_benefits_attributes]['0'][:kind]).to eq(:dental)
          end

          it 'returns valid params for dental' do
            result = dental_builder.build
            expect(result).to be_a(ActionController::Parameters)
            expect(result).to be_permitted
          end

          it 'includes contribution levels' do
            result = dental_builder.build
            expect(result[:sponsored_benefits_attributes]['0'][:sponsor_contribution_attributes]).to be_present
            expect(result[:sponsored_benefits_attributes]['0'][:sponsor_contribution_attributes][:contribution_levels_attributes]).to be_present
          end
        end

        context 'benefit_kind method' do
          it 'returns :dental when benefit_type is dental' do
            expect(dental_builder.send(:benefit_kind)).to eq(:dental)
          end

          it 'returns :health when benefit_type is not specified' do
            health_params = ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              reference_plan_id: product.id.to_s
            )
            builder = described_class.new(health_params)
            expect(builder.send(:benefit_kind)).to eq(:health)
          end

          it 'converts string to symbol' do
            params_with_string = ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              benefit_type: 'DENTAL',
              reference_plan_id: dental_product&.id&.to_s || BSON::ObjectId.new.to_s
            )
            builder = described_class.new(params_with_string)
            expect(builder.send(:benefit_kind)).to eq(:dental)
          end
        end
      end

      describe 'existing_sponsored_benefit_id for dental' do
        let(:test_benefit_package) do
          FactoryBot.create(
            :benefit_sponsors_benefit_packages_benefit_package,
            benefit_application: benefit_application,
            product_package: product_package
          )
        end

        let(:health_sponsored_benefit) do
          test_benefit_package.sponsored_benefits.detect { |sb| sb.is_a?(BenefitSponsors::SponsoredBenefits::HealthSponsoredBenefit) }
        end

        context 'when looking for dental benefit in package with only health' do
          let(:dental_params_with_package) do
            ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              benefit_package_id: test_benefit_package.id.to_s,
              benefit_type: 'dental',
              reference_plan_id: product.id.to_s,
              product_package_kind: 'single_product'
            )
          end

          let(:dental_package_builder) { described_class.new(dental_params_with_package) }

          it 'returns nil when no dental benefit exists' do
            existing_id = dental_package_builder.send(:existing_sponsored_benefit_id)
            expect(existing_id).to be_nil
          end

          it 'does not include package ID in form attrs when adding new benefit type' do
            result = dental_package_builder.build
            expect(result[:id]).to be_nil
          end
        end

        context 'when looking for health benefit in package with health' do
          let(:health_params_with_package) do
            ActionController::Parameters.new(
              benefit_application_id: benefit_application.id.to_s,
              benefit_package_id: test_benefit_package.id.to_s,
              benefit_type: 'health',
              reference_plan_id: product.id.to_s,
              product_package_kind: 'single_issuer'
            )
          end

          let(:health_package_builder) { described_class.new(health_params_with_package) }

          it 'finds existing health benefit' do
            existing_id = health_package_builder.send(:existing_sponsored_benefit_id)
            expect(existing_id).to eq(health_sponsored_benefit.id)
          end

          it 'includes package ID when benefit type already exists' do
            result = health_package_builder.build
            expect(result[:id]).to eq(test_benefit_package.id.to_s)
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end