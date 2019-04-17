module BenefitSponsors
  class EmployerDatatableSerializer < ActiveModel::Serializer
    include FastJsonapi::ObjectSerializer
    extend ::ApplicationHelper
    attributes :legal_name, :aasm_state, :hbx_id

    attribute :source_kind do |benefit_sponsorship|
      benefit_sponsorship.source_kind.to_s.humanize
    end

    attribute :fein do |benefit_sponsorship|
      benefit_sponsorship.organization.fein
    end

    attribute :broker do |benefit_sponsorship|
      benefit_sponsorship.organization.employer_profile.try(:active_broker_agency_legal_name).try(:titleize)
    end

    attribute :plan_year_state do |benefit_sponsorship|
      if benefit_sponsorship.latest_benefit_application.present?
        benefit_application_summarized_state(benefit_sponsorship.latest_benefit_application)
      end
    end

    attribute :effective_date do |benefit_sponsorship|
      if benefit_sponsorship.latest_benefit_application.present?
        benefit_sponsorship.latest_benefit_application.effective_period.min.strftime("%m/%d/%Y")
      end
    end

    attribute :invoiced? do |benefit_sponsorship|
      benefit_sponsorship.organization.employer_profile.current_month_invoice.present?
    end

    attribute :attestation_status do |benefit_sponsorship|
      if benefit_sponsorship.employer_attestation.present?
        benefit_sponsorship.employer_attestation.aasm_state.titleize
      end
    end

    attribute :actions_menu_items do |benefit_sponsorship|
      {
        "benefit_sponsorship_id": benefit_sponsorship.id,
        "latest_benefit_sponsorship_id": benefit_sponsorship.organization.employer_profile.latest_benefit_sponsorship.id,
        "employer_profile_id": benefit_sponsorship.organization.employer_profile.id,
        "people_id": Person.where({"employer_staff_roles.employer_profile_id" => benefit_sponsorship.organization.employer_profile._id}).map(&:id)
      }
    end

  end
end
