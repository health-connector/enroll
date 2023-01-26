# frozen_string_literal: true

module BenefitSponsors
  module BenefitPackages
    class BenefitPackagesController < ApplicationController

      before_action :check_for_late_rates, only: [:new]

      include Pundit

      layout "two_column", except: :estimated_employee_cost_details

      def new
        authorize @benefit_package_form, :updateable?
      end

      def create
        @benefit_package_form = BenefitSponsors::Forms::BenefitPackageForm.for_create(benefit_package_params)
        authorize @benefit_package_form, :updateable?
        if @benefit_package_form.save
          flash[:notice] = "Benefit Package successfully created."
          # TODO: get redirection url from service
          if params[:add_new_benefit_package] == "true"
            redirect_to new_benefit_sponsorship_benefit_application_benefit_package_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application, add_new_benefit_package: true)
          elsif params[:add_dental_benefits] == "true"
            redirect_to new_benefit_sponsorship_benefit_application_benefit_package_sponsored_benefit_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application, @benefit_package_form.show_page_model, kind: "dental")
          elsif params[:estimated_employee_costs] == "true"
            redirect_to estimated_employee_cost_details_benefit_sponsorship_benefit_application_benefit_package_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application,
                                                                                                                     @benefit_package_form.service.benefit_application.benefit_packages.last)
          else
            redirect_to profiles_employers_employer_profile_path(@benefit_package_form.service.employer_profile, :tab => 'benefits')
          end
        else
          flash[:error] = error_messages(@benefit_package_form)
          render :new
        end
      end

      def edit
        @benefit_package_form = BenefitSponsors::Forms::BenefitPackageForm.for_edit(params.permit(:id, :benefit_application_id), true)
        authorize @benefit_package_form, :updateable?
      end

      def update
        @benefit_package_form = BenefitSponsors::Forms::BenefitPackageForm.for_update(benefit_package_params.merge({:id => params.require(:id)}))
        if @benefit_package_form.update
          flash[:notice] = "Benefit Package successfully updated."
          # TODO: get redirection url from service
          if params[:add_new_benefit_package] == "true"
            redirect_to new_benefit_sponsorship_benefit_application_benefit_package_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application, add_new_benefit_package: true)
          elsif params[:add_dental_benefits] == "true"
            redirect_to new_benefit_sponsorship_benefit_application_benefit_package_sponsored_benefit_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application, @benefit_package_form.show_page_model, kind: "dental")
          elsif params[:edit_dental_benefits] == "true"
            redirect_to edit_benefit_sponsorship_benefit_application_benefit_package_sponsored_benefit_path(@benefit_package_form.service.benefit_application.benefit_sponsorship,
                                                                                                            @benefit_package_form.show_page_model.benefit_application,
                                                                                                            @benefit_package_form.show_page_model, @benefit_package_form.show_page_model.dental_sponsored_benefit, kind: "dental")
          elsif params[:estimated_employee_costs] == "true"
            redirect_to estimated_employee_cost_details_benefit_sponsorship_benefit_application_benefit_package_path(@benefit_package_form.service.benefit_application.benefit_sponsorship, @benefit_package_form.show_page_model.benefit_application,
                                                                                                                     @benefit_package_form.service.benefit_application.benefit_packages.where(id: params[:id]).last)
          else
            redirect_to profiles_employers_employer_profile_path(@benefit_package_form.service.benefit_application.benefit_sponsorship.profile, :tab => 'benefits')
          end
        else
          flash[:error] = error_messages(@benefit_package_form)
          render :edit
        end
      end

      def calculate_employer_contributions
        @employer_contributions = BenefitSponsors::Forms::BenefitPackageForm.for_calculating_employer_contributions(benefit_package_params)
        render json: @employer_contributions
      end

      def calculate_employee_cost_details
        @employee_cost_details = BenefitSponsors::Forms::BenefitPackageForm.for_calculating_employee_cost_details(benefit_package_params)
        render json: @employee_cost_details.to_json
      end

      def estimated_employee_cost_details
        application_id = BSON::ObjectId.from_string(params[:benefit_application_id])
        @benefit_sponsorship = ::BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:"benefit_applications._id" => application_id).first
        @benefit_application = @benefit_sponsorship.benefit_applications.where(id: application_id).first
        @benefit_package = @benefit_application.benefit_packages.where(id: params[:id]).first

        @employee_costs_result = ::BenefitSponsors::Operations::BenefitSponsorship::EstimatedEmployeeCosts.new.call({
                                                                                                                      benefit_application: @benefit_application,
                                                                                                                      benefit_package: @benefit_package,
                                                                                                                      package_kind: params[:kind]
                                                                                                                    }).value!
        respond_to do |format|
          format.html do
            reference_product_index = @employee_costs_result[:employee_costs].find_index(@employee_costs_result[:employee_costs].select{|e| e[:product_id] == @employee_costs_result[:reference_product].id}.first)
            results = @employee_costs_result[:employee_costs].insert(0, @employee_costs_result[:employee_costs].delete_at(reference_product_index))
            @employee_costs = Kaminari.paginate_array(results).page(params[:page]).per(5)
          end
          format.pdf do
            @employee_costs = @employee_costs_result[:employee_costs]
            render :pdf => "estimated_employee_cost"
          end
        end
      end

      def destroy
        @benefit_package_form = BenefitSponsors::Forms::BenefitPackageForm.fetch(params.permit(:id, :benefit_application_id))
        authorize @benefit_package_form, :updateable?
        if @benefit_package_form.destroy
          flash[:notice] = "Benefit Package successfully deleted."
        else
          flash[:error] = error_messages(@benefit_package_form)
        end
        render :js => "window.location = #{profiles_employers_employer_profile_path(@benefit_package_form.service.benefit_application.benefit_sponsorship.profile, :tab => 'benefits').to_json}"
      end

      def reference_product_summary
        @product_summary = BenefitSponsors::Forms::BenefitPackageForm.for_reference_product_summary(reference_product_params, params[:details])
        render json: @product_summary
      end

      private

      def check_for_late_rates
        @benefit_package_form = BenefitSponsors::Forms::BenefitPackageForm.for_new(params.require(:benefit_application_id))
        date = @benefit_package_form.service.benefit_application.start_on.to_date
        redirect_to profiles_employers_employer_profile_path(@benefit_package_form.service.employer_profile, :tab => 'benefits') if BenefitMarkets::Forms::ProductForm.for_new(date).fetch_results.is_late_rate
      end

      def error_messages(object)
        object.errors.full_messages.inject(""){|memo, error| "#{memo}<li>#{error}</li>"}.html_safe
      end

      def benefit_package_params
        params.require(:benefit_package).permit(
          :title, :description, :probation_period_kind, :benefit_application_id, :id,
          :sponsored_benefits_attributes => [:id, :kind, :product_option_choice, :product_package_kind, :reference_plan_id,
                                             {:sponsor_contribution_attributes => [
                                               :contribution_levels_attributes => [:id, :is_offered, :display_name, :contribution_factor,:contribution_unit_id]
                                             ]}]
        )
      end

      def reference_product_params
        params.permit(:benefit_application_id).merge({:sponsored_benefits_attributes => {"0" => {:reference_plan_id => params[:reference_plan_id]} }})
      end

      def employer_contribution_params
        params.permit(:id, :benefit_application_id, :sponsored_benefits_attributes => [:product_package_kind, :reference_plan_id, :id])
      end

      def new_package_url; end

      def dental_benefits_url; end
    end
  end
end
