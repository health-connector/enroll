# frozen_string_literal: true

require 'rails_helper'

module Notifier
  RSpec.describe NoticeKindsController, type: :controller, dbclean: :after_each do
    routes { Notifier::Engine.routes }

    let(:permission) { FactoryBot.create(:permission, can_view_notice_templates: true, can_edit_notice_templates: true) }
    let(:person) { FactoryBot.create(:person) }
    let!(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person, permission_id: permission.id) }
    let(:notice_viewer) { FactoryBot.create(:user, person: person) }
    let(:outsider) { FactoryBot.create(:user, person: FactoryBot.create(:person)) }

    let!(:notice_kind) do
      Notifier::NoticeKind.create!(notice_number: 'DR900', title: 'A Notice', description: 'A description',
                                   recipient: 'Notifier::MergeDataModels::EmployerProfile', event_name: 'a_notice_event')
    end

    before { allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original }

    describe 'GET #index' do
      # This example asserts the legacy datatable assignment, so it pins the flag
      # rather than inheriting whatever the environment sets.
      context 'when the :refactored_datatables flag is disabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false) }

        it 'builds the legacy datatable' do
          sign_in notice_viewer
          get :index

          expect(assigns(:datatable)).to be_a(Effective::Datatables::NoticesDatatable)
          expect(assigns(:notices_datatable_locals)).to be_nil
        end
      end

      context 'when the :refactored_datatables flag is enabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true) }

        it 'builds the table locals instead of the legacy datatable' do
          sign_in notice_viewer
          get :index

          expect(assigns(:datatable)).to be_nil
          expect(assigns(:notices_datatable_locals)[:table]).to be_a(::Datatables::NoticesTable)
        end
      end
    end

    describe 'GET #notices_datatable' do
      context 'when the :refactored_datatables flag is disabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false) }

        it '404s the fragment endpoint' do
          sign_in notice_viewer
          expect { get :notices_datatable }.to raise_error(ActionController::RoutingError)
        end
      end

      context 'when the :refactored_datatables flag is enabled' do
        before { allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true) }

        it 'answers for a user who may view notice templates' do
          sign_in notice_viewer
          get :notices_datatable

          expect(response).to have_http_status(:success)
        end

        it 'denies a user without the notice template permission' do
          sign_in outsider
          get :notices_datatable

          expect(response).to have_http_status(:redirect)
        end

        it 'streams the CSV export of every notice kind' do
          sign_in notice_viewer
          get :notices_datatable, format: :csv

          expect(response.headers['Content-Type']).to eq('text/csv; charset=utf-8')
          expect(response.headers['Content-Disposition']).to include('notices.csv')
          body = response.body.to_a.join
          expect(body).to start_with('Mpi Indicator,Title,Description,Recipient,Last Updated At')
          expect(body).to include('DR900,A Notice,A description')
        end
      end

      # Scoped to the fragment render: the full-page render pulls in the notifier
      # portal chrome and the CKEditor modal.
      context 'fragment body' do
        render_views

        before do
          allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true)
          sign_in notice_viewer
        end

        it 'renders the notices table with its parity classes and no search box' do
          get :notices_datatable

          expect(response.body).to include('class="effective-datatable table table-striped table-hover dataTable no-footer"')
          expect(response.body).to include('col-string col-mpi_indicator')
          expect(response.body).not_to include('dataTables_filter')
        end

        it 'renders the bulk Delete action and the export buttons' do
          get :notices_datatable

          expect(response.body).to include('buttons-bulk-actions')
          expect(response.body).to include('This will remove selected notices. Are you sure?')
          expect(response.body).to include('buttons-csv')
        end
      end
    end
  end
end
