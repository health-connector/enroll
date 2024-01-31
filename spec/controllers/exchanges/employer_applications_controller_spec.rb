# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Exchanges::EmployerApplicationsController, dbclean: :after_each do

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:employer_profile) { benefit_sponsorship.profile }
  let(:person1) { FactoryGirl.create(:person) }

  describe ".index" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1) }

    before :each do
      sign_in(user)
      xhr :get, :index, employers_action_id: "employers_action_#{employer_profile.id}", employer_id: benefit_sponsorship
    end

    it "should render index" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/employer_applications/index")
    end

    context 'when hbx staff role missing' do
      let(:user) { instance_double("User", :has_hbx_staff_role? => false, :person => person1) }

      it 'should redirect when hbx staff role missing' do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/')
      end
    end
  end

  describe "PUT terminate" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1, id: 1) }
    let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person1) }

    context "when user has permissions" do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
      end

      context 'when application in active status' do
        before do
          put :terminate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: TimeKeeper.date_of_record.next_month.end_of_month.to_s, term_reason: "nonpayment", format: :json
        end

        it "should be success" do
          expect(response).to have_http_status(:success)
        end

        it "should terminate the plan year" do
          initial_application.reload
          expect(initial_application.aasm_state).to eq :termination_pending
          expect(JSON.parse(response.body)).to eq({
                                                    'employer_id' => benefit_sponsorship.id.to_s, 'employer_application_id' => initial_application.id.to_s, 'sequence_id' => 1
                                                  })
        end
      end

      context 'when application is termination_pending' do
        before do
          initial_application.update_attributes(aasm_state: 'termination_pending')
          put :terminate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: TimeKeeper.date_of_record.next_month.end_of_month.to_s, term_reason: "nonpayment", format: :json
        end

        it "should be success" do
          expect(response).to have_http_status(:success)
        end

        it "should not terminate the plan year" do
          initial_application.reload
          expect(initial_application.aasm_state).to eq :termination_pending
          expect(JSON.parse(response.body)).to eq({
                                                    'employer_id' => benefit_sponsorship.id.to_s, 'employer_application_id' => initial_application.id.to_s,
                                                    'sequence_id' => 0, 'errors' => ["This tool cannot terminate an application in termination-pending state."]
                                                  })
        end
      end
    end

    it "should not be a success when user doesn't have permissions" do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: false))
      sign_in(user)
      put :terminate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: initial_application.start_on.next_month, term_reason: "nonpayment", format: :json
      expect(response).to have_http_status(403)
      expect(flash[:error]).to match(/Access not allowed/)
    end

    unless allow_mid_month_voluntary_terms? || allow_mid_month_non_payment_terms?
      context 'non-mid month terminations' do

        before :each do
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :terminate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: TimeKeeper.date_of_record.next_month.end_of_month.prev_day.to_s, term_reason: "nonpayment", term_kind: "nonpayment", format: :json
        end

        it 'should display appropriate error message' do
          expect(JSON.parse(response.body)['errors']).to eq ["Exchange doesn't allow mid month non payment terminations"]
        end
      end
    end
  end

  describe "PUT cancel" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1, id: 1) }
    let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person1) }

    context "when user has permissions" do
      before :each do
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :enrollment_open)
        put :cancel, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: initial_application.start_on.next_month, format: :json
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
      put :cancel, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id, end_on: initial_application.start_on.next_month, format: :json
      expect(response).to have_http_status(403)
      expect(flash[:error]).to match(/Access not allowed/)
    end
  end

  describe "get term reasons" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1) }
    let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person1) }

    before :each do
      allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
      sign_in(user)
      get :get_term_reasons, { reason_type_id: "term_actions_nonpayment" },  format: :js
    end

    it "should be success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "PUT reinstate" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1, id: "12345") }
    let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person1) }

    context 'Success' do
      before :each do
        allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_reinstate).and_return(true)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
        sign_in(user)
        initial_application.update_attributes!(:aasm_state => :terminated)
        put :reinstate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
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
        put :reinstate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
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
        put :reinstate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
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
        put :reinstate, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
      end

      it 'should have redirect response' do
        expect(response).to have_http_status(302)
      end
    end

    context "application history" do
      let(:user) { instance_double("User", :has_hbx_staff_role? => true, :person => person1) }
      let(:hbx_staff_role) { FactoryGirl.create(:hbx_staff_role, person: person1) }

      context 'when feature enabled' do
        before :each do
          allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_history).and_return(true)
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :application_history, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
        end

        it 'returns success' do
          expect(response).to have_http_status(200)
        end
      end


      context 'when feature disabled' do
        before :each do
          allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_history).and_return(false)
          allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', can_modify_plan_year: true))
          sign_in(user)
          put :application_history, employer_application_id: initial_application.id, employer_id: benefit_sponsorship.id
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
end