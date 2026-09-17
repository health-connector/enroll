# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrokerAgencies::QuotesController, type: :controller, dbclean: :after_each do
  let(:person){create(:person, :with_broker_role)}
  let(:user){create(:user, person: person)}
  let(:quote){create :quote, :with_household_and_members}
  let(:quote_benefit_group) { build_stubbed :quote_benefit_group }
  let(:quote_attributes) { FactoryBot.attributes_for(:quote) }
  let(:quote_household_attributes) { FactoryBot.attributes_for(:quote_household) }
  let(:quote_member_attributes) { FactoryBot.attributes_for(:quote_member) }

  before do
    person.broker_role.aasm_state = 'active'
    sign_in user
  end

  describe "Create"  do
    context "with valid quote params" do
      it "should save quote" do
        expect do
          post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        end.to change(Quote,:count).by(1)
      end
      it "should redirect to edit page" do
        post :create,  params: {  broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(assigns(:quote)).to be_a(Quote)
        expect(response).to redirect_to(edit_broker_agencies_broker_role_quote_path(person.broker_role.id,assigns(:quote).id))
      end
    end
    context "with valid quote params and nested quote household and member" do
      before do
        quote_household_attributes["quote_members_attributes"] = { "0" => quote_member_attributes }
        quote_attributes["quote_benefit_groups_attributes"] = {"0" => {"title" => "Default Benefit Package"}}
        quote_attributes["quote_households_attributes"] = { "0" => quote_household_attributes }
      end
      it "should save quote" do
        expect do
          post :create, params: {  broker_role_id: person.broker_role.id, quote: quote_attributes }
        end.to change(Quote, :count).by(1)
      end
      it "should save household info" do
        post :create, params: {  broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(assigns(:quote)).to be_a(Quote)
        expect(assigns(:quote).quote_households.size).to eq 1
        expect(assigns(:quote).quote_households.first.family_id.to_s).to eq quote_household_attributes[:family_id].to_s
      end
      it "should save household member attributes" do
        post :create, params: {  broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(assigns(:quote)).to be_a(Quote)
        expect(assigns(:quote).quote_households.size).to eq 1
        expect(assigns(:quote).quote_households.first.quote_members.first.first_name).to eq quote_member_attributes[:first_name]
      end
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "Update" do
    before do
      @quote = FactoryBot.create(:quote,:with_household_and_members)
    end

    context "update quote name" do
      before do
        put :update, params: {  broker_role_id: person.broker_role.id, :id => @quote.id, quote: quote_attributes.merge!({quote_name: "New Name"}) }
        @quote.reload
      end
      it "should update quote name" do
        expect(@quote.quote_name).to eq "New Name"
      end
      it "should redirect to edit page" do
        expect(response).to redirect_to(edit_broker_agencies_broker_role_quote_path(person.broker_role.id,@quote.id))
      end
    end

    context "update quote start on date" do
      before do
        put :update, params: {  broker_role_id: person.broker_role.id, :id => @quote.id, quote: quote_attributes.merge!({start_on: "2016-09-06"}) }
        @quote.reload
      end
      it "should update quote name" do
        expect(@quote.start_on.strftime("%Y-%m-%d")).to eq "2016-09-06"
      end
      it "should redirect to edit page" do
        expect(response).to redirect_to(edit_broker_agencies_broker_role_quote_path(person.broker_role.id,@quote.id))
      end
    end

    context "update quote member name and dob" do
      before do
        quote_household_attributes.merge!("id" => @quote.quote_households.first.id, "quote_members_attributes" => { "0" => {"first_name" => "Thomas",
                                                                                                                            "middle_name" => "M", "dob" => "07/04/1990", "id" => @quote.quote_households.first.quote_members.first.id } })
        quote_attributes[:quote_benefit_groups_attributes] = {"0" => {"title" => "Default Benefit Package"}}
        quote_attributes[:quote_households_attributes] = {"0" => quote_household_attributes }
        put :update, params: {  broker_role_id: person.broker_role.id, :id => @quote.id, quote: quote_attributes }
        @quote.reload
      end
      it "should update quote member first name" do
        expect(@quote.quote_households.first.quote_members.count).to eq 1
        expect(@quote.quote_households.first.quote_members.first.first_name).to eq "Thomas"
      end
      it "should update quote member dob" do
        expect(@quote.quote_households.first.quote_members.count).to eq 1
        expect(@quote.quote_households.first.quote_members.first.dob.strftime("%Y/%m/%d")).to eq "1990/07/04"
      end
      it "should redirect to edit page" do
        expect(response).to redirect_to(edit_broker_agencies_broker_role_quote_path(person.broker_role.id,@quote.id))
      end
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "Delete" do
    before do
      @quote = FactoryBot.create(:quote,:with_household_and_members)
    end
    context "#delete_quote" do
      it "should delete quote" do
        expect do
          delete :delete_quote,  params: {  broker_role_id: person.broker_role.id, :id => @quote.id }
        end.to change(Quote,:count).by(-1)
      end

      it "should redirect to my quote index page" do
        delete :delete_quote, params: {  broker_role_id: person.broker_role.id, :id => @quote.id }
        expect(response).to redirect_to(my_quotes_broker_agencies_broker_role_quotes_path)
      end
    end

    context "#delete_household" do
      it "should delete quote household" do
        delete :delete_household,  params: {  broker_role_id: person.broker_role.id, :id => @quote.id, :household_id => @quote.quote_households.first.id }, xhr: true
        @quote.reload
        expect(@quote.quote_households).to eq []
      end
    end

    context "#delete_member" do
      it "should delete quote member" do
        delete :delete_member, params: {  :id => @quote.id, broker_role_id: person.broker_role.id,
                                          :household_id => @quote.quote_households.first.id,
                                          :member_id => @quote.quote_households.first.quote_members.first.id }, xhr: true
        @quote.reload
        expect(@quote.quote_households.first.quote_members).to eq []
      end
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "GET new" do

    it "should render the new template" do
      get :new, params: {  broker_role_id: person.broker_role.id }
      expect(response).to have_http_status(302)
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "GET my_quotes" do

    it "returns http success" do
      get :my_quotes, params: {  broker_role_id: person.broker_role.id }
      expect(response).to have_http_status(:success)
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "GET edit" do

    before do
      quote.update_attributes(broker_role_id: person.broker_role.id)
    end

    it "returns http success" do
      get :edit, params: {  broker_role_id: person.broker_role.id, id: quote }
      expect(response).to have_http_status(:success)
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "POST publish_quote" do
    it "should publish_quote" do
      quote.quote_benefit_groups.first.relationship_benefit_for("employee").update_attributes!(:premium_pct => "60")
      allow(quote).to receive(:may_publish?).and_return(true)
      post :publish_quote, params: {  broker_role_id: person.broker_role.id, id: quote }
      expect(response).to have_http_status(:success)
      expect(flash[:notice]).to match "Quote Published"
    end

    it "should redirect if not able to publish" do
      quote.update_attributes(aasm_state: 'published')
      post :publish_quote, params: {  broker_role_id: person.broker_role.id, id: quote }
      expect(response).to have_http_status(:redirect)
    end

    it "should log this issue when invalid received invalid broker_role_id" do
      expect(controller).to receive(:log)
      allow(controller).to receive(:raise).and_return nil
      post :publish_quote, params: {  broker_role_id: "person.broker_role.id", id: quote }
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end

  describe "Creating New Quote " do
    before do
      @quote = FactoryBot.create(:quote,:with_household_and_members)
      quote_household_attributes.merge!("id" => @quote.quote_households.first.id, "quote_members_attributes" => { "0" => {"first_name" => "Kevin",
                                                                                                                          "middle_name" => "M", "dob" => "07/04/1990", "id" => @quote.quote_households.first.quote_members.first.id } })
      quote_attributes[:quote_benefit_groups_attributes] = {"0" => {"title" => "Default Benefit Package"}}
      quote_attributes[:quote_households_attributes] = {"0" => quote_household_attributes }
      put :update, params: {  commit: 'Create Quote',broker_role_id: person.broker_role.id, :id => @quote.id, quote: quote_attributes }
      @quote.reload
    end

    context "creating a new quote by Create Quote button" do
      before do
        put :update, params: {  broker_role_id: person.broker_role.id, :id => @quote.id, commit: 'Create Quote', quote: quote_attributes.merge!({quote_name: "Create Nuote Name", start_on: "2016-09-06"}) }
        @quote.reload
      end
      it "should create quote new name" do
        expect(@quote.quote_name).to eq "Create Nuote Name"
      end
      it "should create quote name" do
        expect(@quote.start_on.strftime("%Y-%m-%d")).to eq "2016-09-06"
      end
      it "should create quote member first name" do
        expect(@quote.quote_households.first.quote_members.count).to eq 1
        expect(@quote.quote_households.first.quote_members.first.first_name).to eq "Kevin"
      end
      it "should create quote member dob" do
        expect(@quote.quote_households.first.quote_members.count).to eq 1
        expect(@quote.quote_households.first.quote_members.first.dob.strftime("%Y/%m/%d")).to eq "1990/07/04"
      end
      it "should redirect to next step and publish" do
        expect(response).to redirect_to(broker_agencies_broker_role_quote_path(person.broker_role.id,@quote.id))
      end
    end

    context "without valid broker role" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "should redirect user" do
        post :create, params: { broker_role_id: person.broker_role.id, quote: quote_attributes }
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end
  end
  describe "Action # quotes_datatable (:refactored_datatables)", dbclean: :after_each do
    render_views

    let!(:broker_quote) do
      FactoryBot.create(:quote, broker_role_id: person.broker_role.id, quote_name: 'Summer Quote',
                                employer_type: 'prospect', aasm_state: 'draft')
    end
    let!(:other_brokers_quote) do
      FactoryBot.create(:quote, broker_role_id: FactoryBot.create(:broker_role).id, quote_name: 'Someone Elses Quote',
                                employer_type: 'prospect', aasm_state: 'draft')
    end

    before do
      allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true)
    end

    context "when the :refactored_datatables flag is disabled" do
      before do
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false)
      end

      it "404s the fragment endpoint" do
        expect do
          get :quotes_datatable, params: { broker_role_id: person.broker_role.id }, format: :html
        end.to raise_error(ActionController::RoutingError)
      end

    end

    context "when the broker role is not active" do
      before do
        person.broker_role.aasm_state = 'applicant'
      end

      it "denies access" do
        get :quotes_datatable, params: { broker_role_id: person.broker_role.id }, format: :html
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to match(/Access not allowed for broker_role_policy/)
      end
    end

    context "when authorized with the flag enabled" do
      it "renders the table fragment without a layout" do
        get :quotes_datatable, params: { broker_role_id: person.broker_role.id }, format: :html
        expect(response).to have_http_status(:success)
        expect(response).to render_template(partial: 'datatables/_table')
        expect(response.body).to include('Summer Quote')
      end

      it "scopes the fragment to the route broker" do
        get :quotes_datatable, params: { broker_role_id: person.broker_role.id }, format: :html
        expect(response.body).not_to include('Someone Elses Quote')
      end

      it "ignores a collection_scope param naming another broker" do
        scoped_params = { broker_role_id: person.broker_role.id, collection_scope: other_brokers_quote.broker_role_id.to_s }
        get :quotes_datatable, params: scoped_params, format: :html
        expect(response.body).to include('Summer Quote')
        expect(response.body).not_to include('Someone Elses Quote')
      end

      it "narrows the fragment by the filter tab scopes" do
        filtered_params = { broker_role_id: person.broker_role.id, employer_types: 'prospect', states: 'published' }
        get :quotes_datatable, params: filtered_params, format: :html
        expect(response.body).not_to include('Summer Quote')
      end

      it "narrows the fragment by the quote-name search" do
        get :quotes_datatable, params: { broker_role_id: person.broker_role.id, search: 'Summer' }, format: :html
        expect(response.body).to include('Summer Quote')
      end

      it "streams the full filtered set as CSV" do
        get :quotes_datatable, params: { broker_role_id: person.broker_role.id }, format: :csv
        expect(response.headers['Content-Type']).to include('text/csv')
        expect(response.headers['Content-Disposition']).to match(/quotes\.csv/)
        rows = CSV.parse(response.body.to_a.join)
        expect(rows.first).to eq(['Employer Name', 'Employer Type', 'Quote', 'Effective Date', 'Claim Code',
                                  'Family Count', 'State'])
        expect(rows.length).to eq(2)
      end
    end
  end
  describe "Action # my_quotes (:refactored_datatables)", dbclean: :after_each do
    before do
      allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true)
    end

    it "builds the new table locals when the flag is enabled" do
      get :my_quotes, params: { broker_role_id: person.broker_role.id }, format: :html
      expect(assigns(:datatable)).to be_nil
      locals = assigns(:quotes_datatable_locals)
      expect(locals[:table]).to be_a(Datatables::QuotesTable)
      expect(locals[:url]).to eq(quotes_datatable_broker_agencies_broker_role_quotes_path(person.broker_role.id))
    end

    it "builds the legacy datatable when the flag is disabled" do
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false)
      get :my_quotes, params: { broker_role_id: person.broker_role.id }, format: :html
      expect(assigns(:datatable)).to be_a(Effective::Datatables::QuoteDatatable)
      expect(assigns(:quotes_datatable_locals)).to be_nil
    end
  end
end
