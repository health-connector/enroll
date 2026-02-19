# frozen_string_literal: true

module BenefitSponsors
  module Services
    # Service to build form parameters for BenefitPackageForm
    # Handles parameter validation and benefit package existence checks
    class BenefitPackageFormParamsBuilder
      attr_reader :params

      def initialize(params)
        @params = params
      end

      # Build form parameters compatible with BenefitPackageForm
      # @return [ActionController::Parameters, nil] Permitted parameters or nil if invalid
      def build
        return nil unless valid_params?

        form_attrs = base_form_attributes
        form_attrs[:id] = package_id if package_exists? && package_id.present?
        form_attrs[:sponsored_benefits_attributes] = { "0" => sponsored_benefit_attributes }

        ActionController::Parameters.new(form_attrs).permit!
      end

      private

      def valid_params?
        params[:reference_plan_id].present? && params[:benefit_application_id].present?
      end

      def base_form_attributes
        {
          benefit_application_id: params[:benefit_application_id],
          sponsored_benefits_attributes: {}
        }
      end

      def sponsored_benefit_attributes
        attrs = {
          kind: :health,
          reference_plan_id: params[:reference_plan_id],
          product_package_kind: params[:product_package_kind],
          product_option_choice: params[:product_option_choice]
        }.compact

        # Only include ID if we have a valid existing benefit package with sponsored benefits
        attrs[:id] = existing_sponsored_benefit_id if package_exists? && existing_sponsored_benefit_id.present?

        attrs[:sponsor_contribution_attributes] = contribution_attributes if params[:contribution_levels].present?
        attrs
      end

      def contribution_attributes
        contribution_levels_attrs = {}

        params[:contribution_levels].each do |index, level_data|
          contribution_levels_attrs[index] = {
            contribution_factor: level_data[:contribution_factor],
            is_offered: level_data[:is_offered],
            display_name: level_data[:display_name],
            contribution_unit_id: level_data[:contribution_unit_id]
          }.compact
        end

        { contribution_levels_attributes: contribution_levels_attrs }
      end

      def package_id
        @package_id ||= params[:benefit_package_id] || params[:id]
      end

      def package_exists?
        return false unless package_id.present?

        @package_exists ||= check_package_existence
      end

      def check_package_existence
        application_id = BSON::ObjectId.from_string(params[:benefit_application_id])
        benefit_sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship
                              .where(:"benefit_applications._id" => application_id).first

        return false unless benefit_sponsorship

        benefit_application = benefit_sponsorship.benefit_applications.find(application_id)
        benefit_application.benefit_packages.where(id: package_id).exists?
      rescue StandardError => e
        Rails.logger.warn("Could not verify benefit package existence: #{e.message}")
        false
      end

      def existing_sponsored_benefit_id
        return nil unless package_id.present?

        application_id = BSON::ObjectId.from_string(params[:benefit_application_id])
        benefit_sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship
                              .where(:"benefit_applications._id" => application_id).first
        return nil unless benefit_sponsorship

        benefit_application = benefit_sponsorship.benefit_applications.find(application_id)
        benefit_package = benefit_application.benefit_packages.find(package_id)
        benefit_package.sponsored_benefits.first&.id
      rescue StandardError => e
        Rails.logger.warn("Could not find existing sponsored benefit: #{e.message}")
        nil
      end
    end
  end
end