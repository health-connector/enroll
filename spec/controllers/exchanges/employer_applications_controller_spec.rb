# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Exchanges::EmployerApplicationsController, dbclean: :after_each do
  include ActionDispatch::TestProcess

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:employer_profile) { benefit_sponsorship.profile }
  let(:person1) { FactoryBot.create(:person) }
  let(:user) { FactoryBot.create(:user, :with_hbx_staff_role, person: person1)}

  describe ".index" do
    before :each do
      sign_in(user)
      get :index, params: { employers_action_id: "employers_action_#{employer_profile.id}", employer_id: benefit_sponsorship }, xhr: true
    end

    it "should render index" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/employer_applications/index")
    end

    context 'when hbx staff role missing' do
      let(:user) { FactoryBot.create(:user, person: person1)}

      it 'should redirect when hbx staff role missing' do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/')
      end
    end
  end

  describe "PUT terminate" do
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1) }

    context "when user has permissions" do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        put :terminate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: TimeKeeper.date_of_record.next_month.end_of_month, term_reason: "nonpayment" }, format: :json
      end

      context 'when application in active status' do
        it "should be success" do
          expect(response).to have_http_status(:success)
        end

        it "should terminate the plan year" do
          initial_application.reload
          expect(initial_application.aasm_state).to eq :termination_pending
          expect(JSON.parse(response.body)).to eq({'employer_id' => benefit_sponsorship.id.to_s, 'employer_application_id' => initial_application.id.to_s, 'sequence_id' => 1})
        end
      end

      context 'when application is termination_pending' do
        before do
          initial_application.update_attributes(aasm_state: 'termination_pending')
          put :terminate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: TimeKeeper.date_of_record.next_month.end_of_month.to_s, term_reason: "nonpayment" }, format: :json
        end

        it "should be success" do
          expect(response).to have_http_status(:success)
        end

        it "should not terminate the plan year" do
          initial_application.reload
          expect(initial_application.aasm_state).to eq :termination_pending
          expect(JSON.parse(response.body)).to eq({
                                                    'employer_id' => benefit_sponsorship.id.to_s, 'employer_application_id' => initial_application.id.to_s,
                                                    'sequence_id' => 1, 'errors' => ["This tool cannot terminate an application in termination-pending state."]
                                                  })
        end
      end
    end

    it "should not be a success when user doesn't have permissions" do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: false))
      sign_in(user)
      put :terminate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: initial_application.start_on.next_month, term_reason: "nonpayment" }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/Access not allowed/)
    end

    unless allow_mid_month_voluntary_terms? || allow_mid_month_non_payment_terms?
      context 'non-mid month terminations' do

        before :each do
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :terminate, format: :json, params: {
            employer_application_id: initial_application.id,
            employer_id: benefit_sponsorship.id,
            end_on: TimeKeeper.date_of_record.next_month.end_of_month.prev_day,
            term_reason: "nonpayment", term_kind: "nonpayment"
          }
        end

        it 'should display appropriate error message' do
          expect(JSON.parse(response.body)['errors']).to eq ["Exchange doesn't allow mid month non payment terminations"]
        end
      end
    end
  end

  describe "PUT cancel" do
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1) }
    let(:valid_params) do
      {
        employer_application_id: initial_application.id,
        employer_id: benefit_sponsorship.id,
        end_on: initial_application.start_on.next_month
      }
    end

    context "when user has permissions" do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :enrollment_open)
        put :cancel, params: valid_params, format: :json
      end

      it "should be success" do
        expect(response).to have_http_status(:success)
      end

      it "should cancel the plan year" do
        initial_application.reload
        expect(initial_application.aasm_state).to eq :canceled
      end
    end

    it "should not be a success when user doesn't have permissions" do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: false))
      sign_in(user)
      put :cancel, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: initial_application.start_on.next_month }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to match(/Access not allowed/)
    end
  end

  describe "get term reasons" do
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1) }

    before :each do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
      sign_in(user)
      get :get_term_reasons, params: { reason_type_id: "term_actions_nonpayment" },  format: :js
    end

    it "should be success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "PUT reinstate" do
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1) }

    context 'Success' do
      before :each do
        allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_reinstate).and_return(true)
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:prevent_concurrent_sessions).and_return(false)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :terminated)
        put :reinstate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
      end

      it 'should have redirect response' do
        expect(response).to have_http_status(302)
      end
    end

    context 'Failure NotAuthorized' do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: false))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :terminated)
        put :reinstate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
      end

      it 'should have redirect response' do
        expect(response).to have_http_status(:redirect)
      end

      it 'should return error message' do
        expect(flash[:error]).to eq "Access not allowed for hbx_profile_policy.can_modify_plan_year?, (Pundit policy)"
      end
    end

    context 'Failure Application Not Valid For reinstate' do
      before :each do
        EnrollRegistry[:benefit_application_reinstate].feature.stub(:is_enabled).and_return(true)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :enrollment_eligible)
        put :reinstate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
      end

      it 'should have redirect response' do
        expect(response).to have_http_status(302)
      end
    end

    context 'Feature disabled' do
      before :each do
        EnrollRegistry[:benefit_application_reinstate].feature.stub(:is_enabled).and_return(false)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :enrollment_eligible)
        put :reinstate, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
      end

      it 'should have redirect response' do
        expect(response).to have_http_status(302)
      end
    end

    context "application history" do
      let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1) }

      context 'when feature enabled' do
        before :each do
          allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_history).and_return(true)
          allow(EnrollRegistry).to receive(:feature_enabled?).with(:prevent_concurrent_sessions).and_return(false)
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :application_history, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
        end

        it 'returns success' do
          expect(response).to have_http_status(200)
        end
      end

      context 'when feature disabled' do
        before :each do
          allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_history).and_return(false)
          allow(EnrollRegistry).to receive(:feature_enabled?).with(:prevent_concurrent_sessions).and_return(false)
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :application_history, params: { employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id }
        end

        it 'should have redirect response' do
          expect(response).to have_http_status(:redirect)
        end

        it 'should direct to profile root path' do
          expect(response).to redirect_to(exchanges_hbx_profiles_root_path)
        end
      end
    end
  end

  describe 'post upload_v2_xml', :dbclean => :after_each do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1) }
    let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person1, subrole: "super_admin") }
    let(:filename) { "#{Rails.root}/spec/test_data/employer_digest/tufts_health_direct.xml" }
    let(:file) { fixture_file_upload(filename, 'application/xml') }
    let(:name) { can_generate_v2_xml }

    context "when user has permissions" do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true, can_generate_v2_xml: true, name: 'super_admin'))
        sign_in(user)
        post :upload_v2_xml, params: { employer_application_id: initial_application.id, id: initial_application.id, employer_id: benefit_sponsorship.id, file: file }
      end

      it "does redirect and be success" do
        expect(response).to have_http_status(:redirect)
        expect(flash[:success]).to match "Successfully uploaded V2 digest XML for employer_fein: #{benefit_sponsorship.fein}"
      end
    end
  end
end
