# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

module Components
  class FixEmployerAttestation < MongoidMigrationTask
    def migrate
      organizations = BenefitSponsors::Organizations::Organization.where(:"profiles.employer_attestation.aasm_state" => 'unsubmitted')
      organizations.each do |organization|
        process_organization_attestation(organization)
      end
    end

    private

    def process_organization_attestation(organization)
      if conversion_organization?(organization)
        process_conversion_attestation(organization)
      else
        process_attestation_documents(organization)
      end
    end

    def conversion_organization?(organization)
      ["conversion", "mid_plan_year_conversion"].include?(organization.active_benefit_sponsorship.source_kind.to_s)
    end

    def process_conversion_attestation(organization)
      employer_attestation = get_or_create_employer_attestation(organization)
      update_attestation_states(employer_attestation)
      employer_attestation.save!
      log_attestation_update(organization, employer_attestation.aasm_state)
    end

    def get_or_create_employer_attestation(organization)
      if organization.employer_profile.employer_attestation.present?
        organization.employer_profile.employer_attestation
      else
        organization.employer_profile.create_employer_attestation
      end
    end

    def update_attestation_states(employer_attestation)
      employer_attestation.submit! if employer_attestation.may_submit?
      employer_attestation.approve! if employer_attestation.may_approve?
    end

    def process_attestation_documents(organization)
      organization.employer_profile.employer_attestation.employer_attestation_documents.each do |document|
        update_document_attestation(document)
        log_attestation_update(organization, document.employer_attestation.aasm_state)
      end
    end

    def update_document_attestation(document)
      document.approve_attestation if document.accepted?
      document.deny_attestation if document.rejected?
      document.set_attestation_pending if document.info_needed?
      document.employer_attestation.submit! if document.submitted? && document.employer_attestation.may_submit?
    end

    def log_attestation_update(organization, state)
      puts "updated employer attestation to #{state} for organization #{organization.legal_name}" unless Rails.env.test?
    end
  end
end
