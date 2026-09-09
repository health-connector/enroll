# frozen_string_literal: true

require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

module SponsoredBenefits
  RSpec.describe Organizations::BrokerAgencyProfilesController, type: :controller, dbclean: :around_each do
    include_context 'set up broker agency profile for BQT, by using configuration settings'

    routes { SponsoredBenefits::Engine.routes }

    let(:staff_user) { FactoryBot.create(:user, :with_hbx_staff_role, person: FactoryBot.create(:person)) }
    let(:outsider) { FactoryBot.create(:user, person: FactoryBot.create(:person)) }
    let(:profile_id) { owner_profile.id }

    before do
      allow(controller).to receive(:set_broker_agency_profile_from_user).and_return(true)
      allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original
    end

    describe 'GET #employers' do
      # This example asserts the legacy datatable assignment, so it pins the flag
      # rather than inheriting whatever the environment sets.
      context 'when the :refactored_datatables flag is disabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false) }

        it 'builds the legacy datatable' do
          sign_in staff_user
          get :employers, params: { id: profile_id }

          expect(assigns(:datatable)).to be_a(Effective::Datatables::BrokerAgencyEmployerDatatable)
          expect(assigns(:employers_datatable_locals)).to be_nil
        end
      end

      context 'when the :refactored_datatables flag is enabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true) }

        it 'builds the table locals instead of the legacy datatable' do
          sign_in staff_user
          get :employers, params: { id: profile_id }

          expect(assigns(:datatable)).to be_nil
          expect(assigns(:employers_datatable_locals)[:table]).to be_a(Datatables::BrokerAgencyEmployersTable)
        end
      end
    end

    describe 'GET #employers_datatable' do
      context 'when the :refactored_datatables flag is disabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false) }

        it '404s the fragment endpoint' do
          sign_in staff_user
          expect { get :employers_datatable, params: { id: profile_id } }.to raise_error(ActionController::RoutingError)
        end
      end

      context 'when the :refactored_datatables flag is enabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true) }

        it 'answers for a user who may manage the agency quotes' do
          sign_in staff_user
          get :employers_datatable, params: { id: profile_id }

          expect(response).to have_http_status(:success)
        end

        # The page action carries no authorization of its own, so this endpoint is
        # the only place the legacy datatable's own check is reproduced.
        it 'denies a user with no relationship to the broker agency' do
          sign_in outsider
          get :employers_datatable, params: { id: profile_id }

          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq('Access not allowed for employers_datatable?, (Pundit policy)')
        end

        it 'streams the CSV export of the full filtered set' do
          sign_in staff_user
          get :employers_datatable, params: { id: profile_id }, format: :csv

          expect(response.headers['Content-Type']).to eq('text/csv; charset=utf-8')
          expect(response.headers['Content-Disposition']).to include('broker_agency_employers.csv')
          expect(response.body.to_a.join).to start_with('Legal Name,FEIN,EE Count,ER State,Effective Date,Broker')
        end
      end

      # Scoped to the fragment render: the full-page render pulls in unrelated
      # broker portal chrome.
      context 'fragment body' do
        render_views

        before do
          allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true)
          sign_in staff_user
        end

        it 'renders the employers table with its parity classes' do
          get :employers_datatable, params: { id: profile_id }

          expect(response.body).to include('class="effective-datatable table table-striped table-hover dataTable no-footer"')
          expect(response.body).to include('col-string col-legal_name')
          expect(response.body).to include('dataTables_filter')
        end

        it 'renders no checkbox column, the individual market being off' do
          get :employers_datatable, params: { id: profile_id }

          expect(response.body).not_to include('bulk-actions-all')
        end
      end
    end
  end
end
