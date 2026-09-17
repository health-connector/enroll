require 'csv'
require 'prawn/table'
class Employers::PremiumStatementsController < ApplicationController
  layout "two_column", only: [:show]
  include Employers::PremiumStatementHelper
  include ::Datatables::FragmentRendering

  def show
    @employer_profile = EmployerProfile.find(params.require(:id))
    authorize @employer_profile, :list_enrollments?
    set_billing_date
    query = Queries::EmployerPremiumStatement.new(@employer_profile, @billing_date)
    @hbx_enrollments =  query.execute.nil? ? [] : query.execute.hbx_enrollments
    if EnrollRegistry.feature_enabled?(:refactored_datatables)
      @premium_billing_datatable_locals = datatable_locals(premium_billing_table, url: premium_billing_datatable_url)
    else
      scopes = { id: @employer_profile.id, billing_date: @billing_date}
      @datatable = Effective::Datatables::PremiumBillingReportDataTable.new(scopes)
    end

    respond_to do |format|
      format.html
      format.js
      format.csv do
        send_data(csv_for(@hbx_enrollments), type: csv_content_type, filename: "DCHealthLink_Premium_Billing_Report.csv")
      end
    end
  end

  # Renders the report's table fragment for Stimulus redraws. The report's CSV
  # export stays on #show, which already sends the full billing period.
  def premium_billing_datatable
    raise ActionController::RoutingError, 'Not Found' unless EnrollRegistry.feature_enabled?(:refactored_datatables)

    @employer_profile = EmployerProfile.find(params.require(:id))
    authorize @employer_profile, :list_enrollments?
    set_billing_date
    render_datatable_fragment(premium_billing_table, url: premium_billing_datatable_url)
  end

  private

  def premium_billing_table
    ::Datatables::PremiumBillingTable.new(@employer_profile, @billing_date)
  end

  def premium_billing_datatable_url
    premium_billing_datatable_employers_premium_statement_path(@employer_profile, billing_date: @billing_date.strftime("%m/%d/%Y"))
  end

  def csv_for(hbx_enrollments)
    (output = "").tap do
      CSV.generate(output) do |csv|
        csv << ["Name", "SSN", "DOB", "Hired On", "Benefit Group", "Type", "Name", "Issuer", "Covered Ct", "Employer Contribution",
        "Employee Premium", "Total Premium"]
        hbx_enrollments.each do |enrollment|
          ee = enrollment.census_employee
          next if ee.blank?
          csv << [  ee.full_name,
                    ee.ssn,
                    ee.dob,
                    ee.hired_on,
                    ee.published_benefit_group.title,
                    enrollment.plan.coverage_kind,
                    enrollment.plan.name,
                    enrollment.plan.carrier_profile.legal_name,
                    enrollment.humanized_members_summary,
                    view_context.number_to_currency(enrollment.total_employer_contribution),
                    view_context.number_to_currency(enrollment.total_employee_cost),
                    view_context.number_to_currency(enrollment.total_premium)
                  ]
        end
      end
    end
  end

  def csv_content_type
    case request.user_agent
      when /windows/i
        'application/vnd.ms-excel'
      else
        'text/csv'
    end
  end

  def set_billing_date
    if params[:billing_date].present?
      @billing_date = DateParser.smart_parse(params[:billing_date])
    else
      @billing_date = billing_period_options.first[1]
    end
  end
end
