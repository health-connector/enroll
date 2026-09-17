# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employers::PremiumStatementsController do
  let(:user) { double("User") }
  let(:person) { FactoryBot.create(:person)}
  let(:employer_profile) { FactoryBot.create(:employer_profile) }
  let(:current_plan_year) { double("PlanYear", enrolled: []) }
  let(:subscriber) { double("HbxEnrollmentMember") }
  let(:carrier_profile){ double("CarrierProfile", legal_name: "my legal name") }
  let(:employee_roles) { [double("EmployeeRole")] }
  let(:benefit_group){ double("BenefitGroup", title: "my benefit group") }

  let(:plan) do
    double(
      "Plan",
      name: "my plan",
      carrier_profile: carrier_profile,
      coverage_kind: "my coverage kind"
    )
  end

  let(:hbx_enrollments) do
    [
    double("HbxEnrollment",
           plan: plan,
           humanized_members_summary: 2,
           total_employer_contribution: 200,
           total_employee_cost: 781.2,
           total_premium: 981.2)
  ]
  end

  let(:census_employee) do
    double("CensusEmployee",
           full_name: "my full name",
           ssn: "my ssn",
           dob: "my dob",
           hired_on: "my hired_on",
           published_benefit_group: benefit_group)
  end

  context "GET show" do
    let(:query_result) { double(:hbx_enrollments => hbx_enrollments) }
    let(:query) { double(:execute => query_result) }

    before do
      allow(user).to receive(:person).and_return(person)
      allow(EmployerProfile).to receive(:find).and_return(employer_profile)
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, TimeKeeper.date_of_record.next_month.beginning_of_month).and_return(query)
      allow(census_employee).to receive(:is_active?).and_return(true)
      hbx_enrollments.each do |hbx_enrollment|
        allow(hbx_enrollment).to receive(:census_employee).and_return(census_employee)
        allow(hbx_enrollment).to receive(:_id).and_return(nil)
      end
    end

    it "should return contribution" do
      sign_in(user)
      get :show, params: { id: "test"}, xhr: true
      expect(response).to have_http_status(:success)
    end
  end

  context "csv export" do
    let(:query_result) { double(:hbx_enrollments => hbx_enrollments) }
    let(:query) { double(:execute => query_result) }

    before do
      allow(user).to receive(:person).and_return(person)
      allow(EmployerProfile).to receive(:find).and_return(employer_profile)
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, TimeKeeper.date_of_record.next_month.beginning_of_month).and_return(query)
      allow(census_employee).to receive(:is_active?).and_return(true)
      @hbx_enrollment = hbx_enrollments.first
      employee_role = employee_roles.first
      allow(@hbx_enrollment).to receive(:subscriber).and_return(subscriber)
      allow(subscriber).to receive(:person).and_return(person)
      allow(person).to receive(:employee_roles).and_return(employee_roles)
      allow(employee_role).to receive(:census_employee).and_return(census_employee)
      allow(census_employee).to receive(:is_active?).and_return(true)
      allow(@hbx_enrollment).to receive(:census_employee).and_return(census_employee)
      allow(@hbx_enrollment).to receive(:_id).and_return(nil)
    end

    it "returns a text/csv content type" do
      sign_in(user)
      get :show, params: { id: "test"}, xhr: true, format: :csv
      expect(response.headers['Content-Type']).to have_content 'text/csv'
    end

    it "returns csv content in the file" do
      sign_in(user)
      get :show, params: { id: "test"}, xhr: true, format: :csv
      expect(response.header["Content-Disposition"]).to match(/DCHealthLink_Premium_Billing_Report/)
      expect(response.body).to have_content(/#{census_employee.full_name}/)
      expect(response.body).to have_content(/#{census_employee.dob}/)
      expect(response.body).to have_content(/#{census_employee.hired_on}/)
      expect(response.body).to have_content(/#{census_employee.ssn}/)
      expect(response.body).to have_content(/#{census_employee.published_benefit_group.title}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.plan.name}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.plan.carrier_profile.legal_name}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.humanized_members_summary}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.total_employer_contribution}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.total_employee_cost}/)
      expect(response.body).to have_content(/#{@hbx_enrollment.total_premium}/)
    end

    # it "returns msvnd excel type" do
    #   request.user_agent = 'application/vnd.ms-excel'
    #   sign_in(user)
    #   xhr :get, :show, id: "test", format: :csv
    #   expect(response.headers['Content-Type']).to have_content 'application/vnd.ms-excel'
    # end
  end

  describe "Action # premium_billing_datatable (:refactored_datatables)" do
    render_views

    let(:query_result) { double(:hbx_enrollments => hbx_enrollments) }
    let(:query) { double(:execute => query_result) }

    before do
      allow(user).to receive(:person).and_return(person)
      allow(EmployerProfile).to receive(:find).and_return(employer_profile)
      allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, TimeKeeper.date_of_record.next_month.beginning_of_month).and_return(query)
      allow(census_employee).to receive(:is_active?).and_return(true)
      hbx_enrollments.each do |hbx_enrollment|
        allow(hbx_enrollment).to receive(:census_employee).and_return(census_employee)
        allow(hbx_enrollment).to receive(:_id).and_return(nil)
      end
      allow(EnrollRegistry).to receive(:feature_enabled?).and_call_original
      allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(true)
      sign_in(user)
    end

    context "when the :refactored_datatables flag is disabled" do
      before do
        allow(EnrollRegistry).to receive(:feature_enabled?).with(:refactored_datatables).and_return(false)
      end

      it "404s the fragment endpoint" do
        expect { get :premium_billing_datatable, params: { id: "test" } }.to raise_error(ActionController::RoutingError)
      end

      it "builds the legacy datatable on show" do
        get :show, params: { id: "test" }, xhr: true
        expect(assigns(:datatable)).to be_a(Effective::Datatables::PremiumBillingReportDataTable)
        expect(assigns(:premium_billing_datatable_locals)).to be_nil
      end
    end

    context "when the user may not list enrollments" do
      let(:permission) { double(list_enrollments: false) }
      let(:hbx_staff_role) { double("hbx_staff_role", permission: permission) }

      before do
        allow(person).to receive(:hbx_staff_role).and_return(hbx_staff_role)
      end

      it "denies access" do
        get :premium_billing_datatable, params: { id: "test" }
        expect(response).not_to have_http_status(:success)
      end
    end

    context "when authorized with the flag enabled" do
      it "renders the table fragment without a layout" do
        get :premium_billing_datatable, params: { id: "test" }
        expect(response).to have_http_status(:success)
        expect(response).to render_template(partial: 'datatables/_table')
        expect(response.body).to include('Employee Profile')
        expect(response.body).to include('COST')
      end

      it "carries the selected billing period on the fragment url" do
        billing_date = TimeKeeper.date_of_record.next_month.beginning_of_month
        allow(Queries::EmployerPremiumStatement).to receive(:new).with(employer_profile, billing_date).and_return(query)
        get :show, params: { id: "test", billing_date: billing_date.strftime("%m/%d/%Y") }, xhr: true
        expect(assigns(:datatable)).to be_nil
        locals = assigns(:premium_billing_datatable_locals)
        expect(locals[:table]).to be_a(Datatables::PremiumBillingTable)
        expect(locals[:url]).to include(CGI.escape(billing_date.strftime("%m/%d/%Y")))
      end

      it "renders the report layout with an All page-length option and no export button" do
        get :premium_billing_datatable, params: { id: "test" }
        expect(response.body).to include('<option value="-1">All</option>')
        expect(response.body).not_to include('buttons-csv')
        expect(response.body).not_to include('dt-buttons')
      end

      it "keeps the full-dataset CSV on the show action rather than the fragment endpoint" do
        get :show, params: { id: "test" }, xhr: true, format: :csv
        expect(response.headers['Content-Type']).to have_content 'text/csv'
        expect(response.header["Content-Disposition"]).to match(/DCHealthLink_Premium_Billing_Report/)
        expect(response.body).to have_content(/#{census_employee.full_name}/)
      end
    end
  end
end
