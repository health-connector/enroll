module BenefitSponsors
  module Profiles
    module Employers
      class EmployerProfilesController < ::BenefitSponsors::ApplicationController

        before_action :find_employer, only: [:show, :inbox, :bulk_employee_upload, :export_census_employees, :coverage_reports, :download_invoice, :show_invoice, :estimate_cost, :run_eligibility_check]
        before_action :load_group_enrollments, only: [:coverage_reports], if: :is_format_csv?
        before_action :check_and_download_invoice, only: [:download_invoice, :show_invoice]
        before_action :wells_fargo_sso, only: [:show]
        layout "two_column", except: [:new]

        #New profile registration with existing organization and approval request submitted to employer
        def show_pending
          authorize BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.new
          respond_to do |format|
            format.html
            format.js
          end
        end

        def show # TODO - Each when clause should be a seperate action.
          authorize @employer_profile

          @tab = params['tab']

          case @tab
          when 'benefits'
            @benefit_sponsorship = @employer_profile.organization.active_benefit_sponsorship
            @benefit_applications = @employer_profile.benefit_applications.non_imported.desc(:start_on, :created_at)
          when 'documents'
            @datatable = ::Effective::Datatables::BenefitSponsorsEmployerDocumentsDataTable.new({employer_profile_id: @employer_profile.id})
            load_documents
          when 'accounts'
            collect_and_sort_invoices(params[:sort_order])
            @benefit_sponsorship = @employer_profile.organization.active_benefit_sponsorship
            @benefit_sponsorship_account = @benefit_sponsorship.benefit_sponsorship_account
            @sort_order = params[:sort_order].nil? || params[:sort_order] == "ASC" ? "DESC" : "ASC"
            #only exists if coming from redirect from sso failing
            @page_num = params[:page_num] if params[:page_num].present?
            if @page_num.present?
              retrieve_payments_for_page(@page_num)
            else
              retrieve_payments_for_page(1)
            end
            respond_to do |format|
              format.js {render 'benefit_sponsors/profiles/employers/employer_profiles/my_account/accounts/payment_history'}

              format.html
            end
          when 'employees'
            @datatable = ::Effective::Datatables::EmployeeDatatable.new(employee_datatable_params)
          when 'brokers'
            @broker_agency_account = @employer_profile.active_broker_agency_account
          when 'inbox'
          when 'families'
            @employees = EmployeeRole.find_by_employer_profile(@employer_profile).select { |ee| CensusEmployee::EMPLOYMENT_ACTIVE_STATES.include?(ee.census_employee.aasm_state)}
          else
            @broker_agency_account = @employer_profile.active_broker_agency_account
            @benefit_sponsorship = @employer_profile.latest_benefit_sponsorship

            if @benefit_sponsorship.present?
              @broker_agency_accounts = @benefit_sponsorship.broker_agency_accounts
              @current_plan_year = @benefit_sponsorship.submitted_benefit_application(include_term_pending: false)
              @business_policy = business_policy_for(@current_plan_year)
            end

            collect_and_sort_invoices(params[:sort_order])
            @sort_order = params[:sort_order].nil? || params[:sort_order] == "ASC" ? "DESC" : "ASC"

            respond_to do |format|
              format.html
              format.js
            end
          end
        end

        def coverage_reports
          authorize @employer_profile
          @billing_date = Date.strptime(params[:billing_date], "%m/%d/%Y") if params[:billing_date]
          @datatable = ::Effective::Datatables::BenefitSponsorsCoverageReportsDataTable.new({ id: params.require(:employer_profile_id), billing_date: @billing_date})

          respond_to do |format|
            format.html
            format.js
            format.csv do
              send_data(csv_for(@group_enrollments), type: csv_content_type, filename: "DCHealthLink_Premium_Billing_Report.csv")
            end
          end
        end

        def run_eligibility_check
          authorize @employer_profile
          benefit_sponsorship = @employer_profile.latest_benefit_sponsorship
          benefit_application = benefit_sponsorship.submitted_benefit_application(include_term_pending: false)
          business_policy = business_policy_for(benefit_application)
          eligibility_hash = if business_policy.is_satisfied?(benefit_application)
                               business_policy.success_results
                             else
                               business_policy.fail_results
                             end
          render :json => eligibility_hash
        end

        def export_census_employees
          authorize @employer_profile
          respond_to do |format|
            format.csv { send_data CensusEmployee.download_census_employees_roster(@employer_profile.id), filename: "#{@employer_profile.legal_name.parameterize.underscore}_census_employees_#{TimeKeeper.date_of_record}.csv" }
          end
        end

        def show_invoice
          authorize @employer_profile

          options = {}
          options[:filename] = @invoice.title
          options[:type] = 'application/pdf'
          options[:disposition] = 'inline'
          send_data Aws::S3Storage.find(@invoice.identifier), options
        end

        def bulk_employee_upload
          authorize @employer_profile

          if params[:file] && !validate_file_upload(params[:file], (FileUploadValidator::CSV_TYPES + FileUploadValidator::XLS_TYPES))
            render :partial => (@roster_upload_form.redirection_url || default_url)
            return
          end

          begin
            file = params.require(:file)
            @roster_upload_form = BenefitSponsors::Forms::RosterUploadForm.call(file, @employer_profile)
            if @roster_upload_form.save
              redirect_to URI.parse(@roster_upload_form.redirection_url).to_s
            else
              render :partial => @roster_upload_form.redirection_url
            end
          rescue Exception => e
            @roster_upload_form ||= BenefitSponsors::Forms::RosterUploadForm.new
            if params.permit(:file).blank?
              @roster_upload_form.errors.add(:base, 'File is missing')
            else
              @roster_upload_form.errors.add(:base, e.message)
            end
            render :partial => (@roster_upload_form.redirection_url || default_url)
          end
        end

        def inbox
          authorize @employer_profile
          @folder = params[:folder] || 'Inbox'
          @sent_box = false
        end

        def download_invoice
          authorize @employer_profile

          options={}
          options[:content_type] = @invoice.type
          options[:filename] = @invoice.title
          send_data Aws::S3Storage.find(@invoice.identifier) , options
        end

        def generate_sic_tree
          sic_tree = SicCode.generate_sic_array
          render :json => sic_tree
        end

        def estimate_cost
          authorize @employer_profile

          find_benefit_package
          estimate_hash = {}
          if @benefit_package.present?
            @benefit_package.sponsored_benefits.each do |sb|
              estimate_hash[sb.product_kind] = map_sponsored_benefit_estimate_cost(sb)
            end
          end
          render :json => estimate_hash
        end

        private

        def wells_fargo_sso
          #grab url for WellsFargoSSO and store in insance variable
          email = @employer_profile.staff_roles.first.present? ? @employer_profile.staff_roles.first.work_email_or_best : nil

          if email.present?
            wells_fargo_sso =
              ::WellsFargo::BillPay::SingleSignOn.new(
                @employer_profile.hbx_id,
                @employer_profile.hbx_id,
                @employer_profile.dba.presence || @employer_profile.legal_name,
                email
              )
          end
          @wf_url = wells_fargo_sso.url if wells_fargo_sso.present? && wells_fargo_sso.token.present?
        end

        def retrieve_payments_for_page(page_no)
          return unless (financial_transactions = @benefit_sponsorship.financial_transactions)

          @payments = financial_transactions.order_by(:paid_on => 'desc').skip((page_no.to_i - 1) * 10).limit(10)
        end

        def check_and_download_invoice
          @invoice = @employer_profile.documents.find(params[:invoice_id])
        end

        def collect_and_sort_invoices(sort_order='ASC')
          @invoices = @employer_profile.invoices
          @invoice_years = (Settings.invoices.minimum_invoice_display_year..TimeKeeper.date_of_record.year).to_a.reverse
          sort_order == 'ASC' ? @invoices.sort_by!(&:date) : @invoices.sort_by!(&:date).reverse! unless @documents
        end

        def find_employer
          id_params = params.permit(:id, :employer_profile_id, :tab)
          id = id_params[:id] || id_params[:employer_profile_id]
          @organization = BenefitSponsors::Organizations::Organization.employer_profiles.where(:"profiles._id" => BSON::ObjectId.from_string(id)).first
          @employer_profile = @organization.employer_profile
          render file: 'public/404.html', status: 404 if @employer_profile.blank?
        end

        def employee_datatable_params
          data_table_params = { id: params[:id], scopes: params[:scopes] }

          data_table_params.merge!({
            renewal: true
          }) if @employer_profile.renewal_benefit_application.present?

          if @employer_profile.off_cycle_benefit_application.present?
            data_table_params[:off_cycle] = true
            data_table_params[:current_py_terminated] = true if @employer_profile.current_benefit_application&.terminated?
          end

          data_table_params[:is_submitted] = true if @employer_profile&.renewal_benefit_application&.is_submitted?
          data_table_params[:is_off_cycle_submitted] = true if @employer_profile&.off_cycle_benefit_application&.is_submitted?
          data_table_params
        end

        def find_benefit_package
          benefit_package_id = params[:benefit_package_id]
          return unless benefit_package_id

          benefit_application = @employer_profile.organization.active_benefit_sponsorship.benefit_applications.where(:"benefit_packages._id" => BSON::ObjectId.from_string(benefit_package_id)).first
          return unless benefit_application

          @benefit_package = benefit_application.benefit_packages.where(:id => benefit_package_id).first
        end

        def map_sponsored_benefit_estimate_cost(sponsored_benefit)
          estimator = ::BenefitSponsors::Services::SponsoredBenefitCostEstimationService.new
          estimate = estimator.calculate_estimates_for_benefit_display(sponsored_benefit)
          estimate.each {|k,v| estimate[k] = ActiveSupport::NumberHelper.number_to_currency(v)}
        end

        def load_documents
          if @employer_profile.employer_attestation.present?
            @documents = @employer_profile.employer_attestation.employer_attestation_documents
          else
            @employer_profile.build_employer_attestation
          end
        end

        def load_group_enrollments
          billing_date = Date.strptime(params[:billing_date], "%m/%d/%Y") if params[:billing_date]
          query = Queries::CoverageReportsQuery.new(@employer_profile, billing_date)
          @group_enrollments =  query.execute
          @product_info = load_products
        end

        def load_products
          current_year = TimeKeeper.date_of_record.year
          previous_year = current_year - 1
          next_year = current_year + 1

          plans = BenefitMarkets::Products::Product.aca_shop_market.by_state(Settings.aca.state_abbreviation)

          current_possible_plans = plans.where(:"application_period.min".in =>[
            Date.new(previous_year, 1, 1),
            Date.new(current_year, 1, 1),
            Date.new(next_year, 1, 1)
          ])

          @product_info = current_possible_plans.inject({}) do |result, product|
            result[product.id] = {
              :title => product.title,
              :kind => product.kind,
              :issuer_name => product.issuer_profile.legal_name
            }
            result
          end
        end

        def default_url
          "/benefit_sponsors/profiles/employers/employer_profiles/employee_csv_upload_errors"
        end

        def csv_for(groups)
          (output = "").tap do
            CSV.generate(output) do |csv|
              csv << ["Name", "SSN", "DOB", "Hired On", "Benefit Group", "Type", "Name", "Issuer", "Covered Ct", "Employer Contribution",
              "Employee Premium", "Total Premium"]
              groups.each do |element|
                primary = element.primary_member
                census_employee = primary.employee_role.census_employee
                sponsored_benefit = primary.sponsored_benefit
                product = @product_info[element.group_enrollment.product[:id]]
                next if census_employee.blank?
                csv << [
                          census_employee.full_name,
                          census_employee.ssn,
                          census_employee.dob,
                          census_employee.hired_on,
                          sponsored_benefit.benefit_package.title,
                          product[:kind],
                          product[:title],
                          product[:issuer_name],
                          (element.members.size - 1),
                          view_context.number_to_currency(element.group_enrollment.sponsor_contribution_total.to_s),
                          view_context.number_to_currency((element.group_enrollment.product_cost_total.to_f - element.group_enrollment.sponsor_contribution_total.to_f).to_s),
                          view_context.number_to_currency(element.group_enrollment.product_cost_total.to_s)
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

        def is_format_csv?
          request.format.csv?
        end

        def user_not_authorized(exception)
          session[:custom_url] = main_app.new_user_registration_path unless current_user
          super
        end

        def business_policy_for(benefit_application)
          enrollment_eligibility_policy = BenefitSponsors::BenefitApplications::AcaShopEnrollmentEligibilityPolicy.new
          enrollment_eligibility_policy.business_policies_for(benefit_application, :end_open_enrollment)
        end
      end
    end
  end
end
