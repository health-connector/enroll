# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
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
        # Use a hash to store dynamic attributes like total_employee_cost
        qhp_attrs = {}
        qhp_double = double('QhpCostShareVariance')
        allow(qhp_double).to receive(:product).and_return(product)
        allow(qhp_double).to receive(:hios_plan_and_variant_id).and_return(product.hios_id)
        allow(qhp_double).to receive(:plan_marketing_name).and_return("#{product.title} Plan")
        allow(qhp_double).to receive(:metal_level).and_return(product.metal_level_kind.to_s.titleize)
        allow(qhp_double).to receive(:issuer_name).and_return(issuer_profile.legal_name)
        allow(qhp_double).to receive(:qhp_service_visits).and_return([])
        allow(qhp_double).to receive(:qhp_deductibles).and_return([])
        allow(qhp_double).to receive(:qhp_maximum_out_of_pockets).and_return([])
        allow(qhp_double).to receive(:qhp_provider_information).and_return(double('ProviderInfo', network_url: 'http://example.com'))
        allow(qhp_double).to receive(:qhp_plan_marketing_links).and_return(double('Links', plan_brochure: 'http://brochure.com'))
        # Support hash-like access for setting/getting total_employee_cost
        allow(qhp_double).to receive(:[]=) { |key, value| qhp_attrs[key] = value }
        allow(qhp_double).to receive(:[]) { |key| qhp_attrs[key] }
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

      describe '#parse_employer_costs_param' do
        it 'parses JSON string and converts keys to BSON::ObjectId' do
          product_id = products.first.id
          employer_costs_json = { product_id.to_s => 500.50 }.to_json

          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(employer_costs: employer_costs_json)
          )

          result = controller.send(:parse_employer_costs_param)
          expect(result).to be_a(Hash)
          expect(result[product_id]).to eq(500.50)
        end

        it 'converts string values to floats' do
          product_id = products.first.id
          employer_costs_json = { product_id.to_s => "683.2" }.to_json

          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(employer_costs: employer_costs_json)
          )

          result = controller.send(:parse_employer_costs_param)
          expect(result[product_id]).to eq(683.2)
          expect(result[product_id]).to be_a(Float)
        end

        it 'returns empty hash for invalid JSON' do
          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(employer_costs: 'invalid json')
          )

          result = controller.send(:parse_employer_costs_param)
          expect(result).to eq({})
        end

        it 'returns empty hash when employer_costs param is not a string' do
          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(employer_costs: { 'test' => 100 })
          )

          result = controller.send(:parse_employer_costs_param)
          expect(result).to eq({})
        end
      end
    end

    describe 'GET #export' do
      let(:valid_export_params) do
        {
          benefit_sponsorship_id: benefit_sponsorship.id.to_s,
          benefit_application_id: benefit_application.id.to_s,
          benefit_package_id: benefit_package.id.to_s,
          plans: plan_ids
        }
      end

      let(:employer_costs) do
        {
          products.first.id => 500.50,
          products.second.id => 600.75,
          products.third.id => 450.25
        }
      end

      before do
        # Mock the render call to avoid actual PDF generation
        allow(controller).to receive(:render)
      end

      context 'without employer costs parameter' do
        it 'renders PDF template' do
          get :export, params: valid_export_params

          expect(controller).to have_received(:render).with(
            hash_including(
              pdf: 'product_comparison_export',
              template: 'benefit_sponsors/benefit_packages/product_comparisons/export',
              disposition: 'attachment'
            )
          )
        end

        it 'loads benefit application' do
          get :export, params: valid_export_params

          expect(assigns(:benefit_application)).to eq(benefit_application)
        end

        it 'loads comparison data' do
          get :export, params: valid_export_params

          expect(assigns(:qhps)).to eq(qhps)
          expect(assigns(:visit_types)).to eq(::Products::Qhp::VISIT_TYPES)
        end

        it 'passes correct locals to template' do
          get :export, params: valid_export_params

          expect(controller).to have_received(:render).with(
            hash_including(
              locals: hash_including(
                qhps: qhps,
                visit_types: ::Products::Qhp::VISIT_TYPES,
                benefit_application: benefit_application
              )
            )
          )
        end
      end

      context 'with employer costs parameter' do
        let(:employer_costs_json) do
          {
            products.first.id.to_s => 500.50,
            products.second.id.to_s => 600.75
          }.to_json
        end

        let(:export_params_with_costs) do
          valid_export_params.merge(employer_costs: employer_costs_json)
        end

        it 'parses and uses passed employer costs' do
          get :export, params: export_params_with_costs

          exported_costs = assigns(:employer_costs)
          expect(exported_costs[products.first.id]).to eq(500.50)
          expect(exported_costs[products.second.id]).to eq(600.75)
        end

        it 'passes parsed employer costs to template' do
          get :export, params: export_params_with_costs

          expect(controller).to have_received(:render).with(
            hash_including(
              locals: hash_including(
                employer_costs: hash_including(products.first.id => 500.50)
              )
            )
          )
        end
      end
    end

    describe 'GET #csv' do
      let(:valid_csv_params) do
        {
          benefit_sponsorship_id: benefit_sponsorship.id.to_s,
          benefit_application_id: benefit_application.id.to_s,
          benefit_package_id: benefit_package.id.to_s,
          plans: plan_ids
        }
      end

      let(:csv_data) { "Carrier,Plan Name,Your Cost\nTest Carrier,Test Plan,$500.00" }

      before do
        allow(::Products::Qhp).to receive(:csv_for).and_return(csv_data)
      end

      context 'without employer costs parameter' do
        it 'loads benefit application' do
          get :csv, params: valid_csv_params

          expect(assigns(:benefit_application)).to eq(benefit_application)
        end

        it 'loads comparison data' do
          get :csv, params: valid_csv_params

          expect(assigns(:qhps)).to eq(qhps)
          expect(assigns(:visit_types)).to eq(::Products::Qhp::VISIT_TYPES)
        end

        it 'sends CSV data' do
          get :csv, params: valid_csv_params

          expect(response).to have_http_status(:success)
          expect(response.body).to eq(csv_data)
        end

        it 'sets correct content type' do
          get :csv, params: valid_csv_params

          expect(response.content_type).to include('csv')
        end

        it 'sets correct filename' do
          get :csv, params: valid_csv_params

          expect(response.headers['Content-Disposition']).to include('plan_comparison_')
          expect(response.headers['Content-Disposition']).to include('.csv')
        end

        it 'adds total_employee_cost to each QHP' do
          get :csv, params: valid_csv_params

          qhps.each do |qhp|
            expect(qhp[:total_employee_cost]).to eq(0.00)
          end
        end
      end

      context 'with employer costs parameter' do
        let(:employer_costs_json) do
          {
            products.first.id.to_s => 500.50,
            products.second.id.to_s => 600.75,
            products.third.id.to_s => 450.25
          }.to_json
        end

        let(:csv_params_with_costs) do
          valid_csv_params.merge(employer_costs: employer_costs_json)
        end

        it 'parses employer costs from parameter' do
          get :csv, params: csv_params_with_costs

          # Check that employer costs were parsed and added to QHPs
          expect(qhps.first[:total_employee_cost]).to eq(500.50)
          expect(qhps.second[:total_employee_cost]).to eq(600.75)
          expect(qhps.third[:total_employee_cost]).to eq(450.25)
        end

        it 'adds employer costs to each QHP as total_employee_cost' do
          get :csv, params: csv_params_with_costs

          qhps.each do |qhp|
            expect(qhp[:total_employee_cost]).to be_a(Float)
            expect(qhp[:total_employee_cost]).to be >= 0
          end
        end

        it 'calls Products::Qhp.csv_for with qhps and visit_types' do
          get :csv, params: csv_params_with_costs

          expect(::Products::Qhp).to have_received(:csv_for).with(qhps, ::Products::Qhp::VISIT_TYPES)
        end

        it 'sends CSV data with correct content type' do
          get :csv, params: csv_params_with_costs

          expect(response).to have_http_status(:success)
          expect(response.body).to eq(csv_data)
        end
      end

      context 'with Windows user agent' do
        before do
          request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        end

        it 'returns Excel content type' do
          get :csv, params: valid_csv_params

          expect(response.content_type).to include('ms-excel')
        end
      end

      context 'with non-Windows user agent' do
        before do
          request.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
        end

        it 'returns CSV content type' do
          get :csv, params: valid_csv_params

          expect(response.content_type).to include('csv')
        end
      end

      context 'with dental benefit type' do
        let(:dental_product_package) { benefit_market_catalog.product_packages.where(package_kind: :single_issuer, benefit_kind: :dental).first }
        let(:dental_products) { dental_product_package&.products&.take(2) || [] }
        let(:dental_plan_ids) { dental_products.map(&:id).map(&:to_s).join(',') }

        let(:dental_qhps) do
          dental_products.map do |product|
            qhp_attrs = {}
            qhp_double = double('DentalQhpCostShareVariance')
            allow(qhp_double).to receive(:product).and_return(product)
            allow(qhp_double).to receive(:hios_plan_and_variant_id).and_return(product.hios_id)
            allow(qhp_double).to receive(:plan_marketing_name).and_return("#{product.title} Dental Plan")
            allow(qhp_double).to receive(:metal_level).and_return('Dental')
            allow(qhp_double).to receive(:issuer_name).and_return(issuer_profile.legal_name)
            allow(qhp_double).to receive(:qhp_service_visits).and_return([])
            allow(qhp_double).to receive(:qhp_deductibles).and_return([])
            allow(qhp_double).to receive(:qhp_maximum_out_of_pockets).and_return([])
            allow(qhp_double).to receive(:[]=) { |key, value| qhp_attrs[key] = value }
            allow(qhp_double).to receive(:[]) { |key| qhp_attrs[key] }
            qhp_double
          end
        end

        before do
          skip 'No dental products available' if dental_products.empty?

          allow(controller).to receive(:load_benefit_application)
          allow(controller).to receive(:load_comparison_data)
          allow(::Products::QhpCostShareVariance).to receive(:find_qhp_cost_share_variances)
            .with(anything, anything, 'Dental')
            .and_return(dental_qhps)

          controller.instance_variable_set(:@benefit_application, benefit_application)
          controller.instance_variable_set(:@qhps, dental_qhps)
          controller.instance_variable_set(:@visit_types, ::Products::Qhp::DENTAL_VISIT_TYPES)
          controller.instance_variable_set(:@employer_costs, {})
        end

        let(:dental_params) do
          {
            benefit_sponsorship_id: benefit_sponsorship.id.to_s,
            benefit_application_id: benefit_application.id.to_s,
            benefit_package_id: benefit_package.id.to_s,
            plans: dental_plan_ids,
            benefit_type: 'dental',
            reference_plan_id: dental_products.first.id.to_s,
            product_package_kind: 'single_product',
            product_option_choice: issuer_profile.id.to_s,
            contribution_levels: {
              '0' => {
                contribution_factor: '55',
                is_offered: '1',
                display_name: 'Employee',
                contribution_unit_id: 'employee'
              }
            },
            format: :json
          }
        end

        it 'returns success response for dental comparison' do
          get :new, params: dental_params
          expect(response).to have_http_status(:success)
        end

        it 'uses dental visit types' do
          get :new, params: dental_params
          expect(controller.instance_variable_get(:@visit_types)).to eq(::Products::Qhp::DENTAL_VISIT_TYPES)
        end

        it 'identifies benefit type as dental' do
          allow(controller).to receive(:params).and_return(ActionController::Parameters.new(dental_params))
          expect(controller.send(:benefit_type)).to eq('dental')
        end
      end
    end

    describe '#benefit_type' do
      it 'defaults to health when not specified' do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new({}))
        expect(controller.send(:benefit_type)).to eq('health')
      end

      it 'returns dental when specified' do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new(benefit_type: 'dental')
        )
        expect(controller.send(:benefit_type)).to eq('dental')
      end

      it 'downcases the benefit type' do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new(benefit_type: 'DENTAL')
        )
        expect(controller.send(:benefit_type)).to eq('dental')
      end
    end

    describe '#visit_types' do
      before do
        allow(controller).to receive(:benefit_type).and_return(benefit_type_value)
      end

      context 'when benefit type is dental' do
        let(:benefit_type_value) { 'dental' }

        it 'returns dental visit types' do
          expect(controller.send(:visit_types)).to eq(::Products::Qhp::DENTAL_VISIT_TYPES)
        end
      end

      context 'when benefit type is health' do
        let(:benefit_type_value) { 'health' }

        it 'returns health visit types' do
          expect(controller.send(:visit_types)).to eq(::Products::Qhp::VISIT_TYPES)
        end
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
