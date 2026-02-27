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
        form_attrs[:sponsored_benefits_attributes] = { "0" => sponsored_benefit_attributes }

        ActionController::Parameters.new(form_attrs).permit!
      end

      private

      def valid_params?
        params[:reference_plan_id].present? && params[:benefit_application_id].present?
      end

      def base_form_attributes
        attrs = {
          benefit_application_id: params[:benefit_application_id],
          sponsored_benefits_attributes: {}
        }

        # For comparison calculations, don't include package ID if we're adding a new benefit type
        # This allows the factory to build a temporary package without trying to update the real one
        if package_exists? && package_id.present?
          # Only include ID if the benefit type already exists in the package
          existing_id = existing_sponsored_benefit_id
          if existing_id.present?
            attrs[:id] = package_id
            Rails.logger.info("Including package ID for existing #{benefit_kind} benefit")
          else
            Rails.logger.info("Skipping package ID - adding new #{benefit_kind} benefit for comparison only")
          end
        end

        attrs
      end

      def sponsored_benefit_attributes
        attrs = {
          kind: benefit_kind,
          reference_plan_id: params[:reference_plan_id],
          product_package_kind: params[:product_package_kind],
          product_option_choice: params[:product_option_choice]
        }.compact

        # Only include ID if we have a valid existing benefit package with sponsored benefits
        existing_id = existing_sponsored_benefit_id if package_exists?
        Rails.logger.info("Existing sponsored benefit ID: #{existing_id.inspect}, package_exists: #{package_exists?}")

        if existing_id.present?
          attrs[:id] = existing_id
          Rails.logger.info("Including sponsored benefit ID in attrs: #{existing_id}")
        else
          Rails.logger.info("No existing sponsored benefit ID, will create new benefit")
        end

        attrs[:sponsor_contribution_attributes] = contribution_attributes if params[:contribution_levels].present?
        Rails.logger.info("Final sponsored_benefit_attributes: #{attrs.inspect}")
        attrs
      end

      def benefit_kind
        # Convert benefit_type param to symbol (:health or :dental)
        # Default to :health for backward compatibility
        kind = params[:benefit_type] || 'health'
        kind.to_s.downcase.to_sym
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

        # Find the sponsored benefit matching the benefit kind (health or dental)
        # Check the class type instead of 'kind' method since it doesn't exist
        sponsored_benefit = if benefit_kind == :dental
                              benefit_package.sponsored_benefits.detect { |sb| sb.is_a?(BenefitSponsors::SponsoredBenefits::DentalSponsoredBenefit) }
                            else
                              benefit_package.sponsored_benefits.detect { |sb| sb.is_a?(BenefitSponsors::SponsoredBenefits::HealthSponsoredBenefit) }
                            end

        Rails.logger.info("Found existing #{benefit_kind} sponsored benefit: #{sponsored_benefit&.id}")
        sponsored_benefit&.id
      rescue StandardError => e
        Rails.logger.warn("Could not find existing sponsored benefit: #{e.message}")
        nil
      end
    end
  end
end