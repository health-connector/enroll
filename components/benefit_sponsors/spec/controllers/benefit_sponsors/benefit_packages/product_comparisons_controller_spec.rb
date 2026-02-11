# frozen_string_literal: true

require 'rails_helper'

module BenefitSponsors
  RSpec.describe BenefitPackages::ProductComparisonsController, type: :controller, dbclean: :after_each do
    routes { BenefitSponsors::Engine.routes }

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
    let(:plan_ids) { products.map(&:id).map(&:to_s).join(',') }

    let(:benefit_package) do
      FactoryBot.create(
        :benefit_sponsors_benefit_packages_benefit_package,
        benefit_application: benefit_application,
        product_package: product_package
      )
    end

    let(:person) { FactoryBot.create(:person) }
    let!(:user) { FactoryBot.create(:user, person: person) }

    before do
      sign_in user
      allow(::Products::QhpCostShareVariance).to receive(:find_qhp_cost_share_variances).and_return(qhps)
    end

    let(:qhps) do
      products.map do |product|
        qhp_double = double('QhpCostShareVariance')
        allow(qhp_double).to receive(:product).and_return(product)
        allow(qhp_double).to receive(:hios_plan_and_variant_id).and_return(product.hios_id)
        allow(qhp_double).to receive(:plan_marketing_name).and_return("#{product.title} Plan")
        allow(qhp_double).to receive(:metal_level).and_return(product.metal_level_kind.to_s.titleize)
        allow(qhp_double).to receive(:issuer_name).and_return(issuer_profile.legal_name)
        allow(qhp_double).to receive(:qhp_service_visit_types).and_return([])
        allow(qhp_double).to receive(:qhp_deductibles).and_return([])
        allow(qhp_double).to receive(:qhp_provider_information).and_return(double('ProviderInfo', network_url: 'http://example.com'))
        allow(qhp_double).to receive(:qhp_plan_marketing_links).and_return(double('Links', plan_brochure: 'http://brochure.com'))
        qhp_double
      end
    end

    describe 'GET #new' do
      context 'with valid parameters' do
        before do
          allow(controller).to receive(:load_benefit_application)
          allow(controller).to receive(:load_comparison_data)
          controller.instance_variable_set(:@benefit_application, benefit_application)
          controller.instance_variable_set(:@qhps, qhps)
          controller.instance_variable_set(:@visit_types, ::Products::Qhp::VISIT_TYPES)
          controller.instance_variable_set(:@employer_costs, {})
        end

        let(:valid_params) do
          {
            benefit_sponsorship_id: benefit_sponsorship.id.to_s,
            benefit_application_id: benefit_application.id.to_s,
            benefit_package_id: benefit_package.id.to_s,
            plans: plan_ids,
            reference_plan_id: products.first.id.to_s,
            product_package_kind: 'single_issuer',
            contribution_levels: {
              '0' => {
                contribution_factor: '0.75',
                is_offered: 'true',
                display_name: 'Employee Only',
                contribution_unit_id: 'employee_only'
              }
            },
            format: :json
          }
        end

        it 'returns success response' do
          get :new, params: valid_params
          expect(response).to have_http_status(:success)
        end

        it 'returns json with success flag' do
          get :new, params: valid_params
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to eq(true)
        end
      end

      context 'with missing benefit_application_id' do
        it 'raises an error when benefit_application_id is missing' do
          invalid_params = {
            benefit_sponsorship_id: benefit_sponsorship.id.to_s,
            benefit_package_id: benefit_package.id.to_s,
            plans: plan_ids,
            format: :json
          }

          expect do
            controller.send(:load_benefit_application)
          end.to raise_error(BSON::ObjectId::Invalid)
        end
      end

      context 'with invalid plan ids' do
        it 'raises an error when plan ids are invalid' do
          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(plans: 'invalid,plan,ids')
          )

          expect do
            controller.send(:requested_plans)
          end.to raise_error(BSON::ObjectId::Invalid)
        end
      end
    end

    describe 'private methods' do
      before do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new(
            benefit_sponsorship_id: benefit_sponsorship.id.to_s,
            benefit_application_id: benefit_application.id.to_s,
            benefit_package_id: benefit_package.id.to_s,
            plans: plan_ids,
            reference_plan_id: products.first.id.to_s,
            product_package_kind: 'single_issuer',
            contribution_levels: {
              '0' => {
                contribution_factor: '0.75',
                is_offered: 'true',
                display_name: 'Employee Only',
                contribution_unit_id: 'employee_only'
              }
            }
          )
        )
      end

      describe '#requested_plans' do
        it 'returns hios ids for the selected products' do
          requested = controller.send(:requested_plans)
          expect(requested).to be_an(Array)
          expect(requested.size).to eq(3)
        end
      end

      describe '#qhps' do
        it 'returns QHP cost share variances' do
          controller.instance_variable_set(:@benefit_application, benefit_application)
          qhp_results = controller.send(:qhps)
          expect(qhp_results).to eq(qhps)
        end
      end

      describe '#calculate_employer_costs' do
        it 'returns a hash of employer costs' do
          controller.instance_variable_set(:@benefit_application, benefit_application)
          controller.instance_variable_set(:@qhps, qhps)

          costs = controller.send(:calculate_employer_costs)
          expect(costs).to be_a(Hash)
        end

        it 'returns empty hash when form params are blank' do
          allow(controller).to receive(:build_form_params).and_return(nil)
          costs = controller.send(:calculate_employer_costs)
          expect(costs).to eq({})
        end
      end

      describe '#build_form_params' do
        it 'delegates to BenefitPackageFormParamsBuilder' do
          builder = instance_double(BenefitSponsors::Services::BenefitPackageFormParamsBuilder)
          allow(BenefitSponsors::Services::BenefitPackageFormParamsBuilder).to receive(:new).and_return(builder)
          allow(builder).to receive(:build).and_return({})

          controller.send(:build_form_params)

          expect(BenefitSponsors::Services::BenefitPackageFormParamsBuilder).to have_received(:new)
          expect(builder).to have_received(:build)
        end
      end
    end
  end
end
