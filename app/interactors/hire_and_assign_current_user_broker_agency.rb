# frozen_string_literal: true

class HireAndAssignCurrentUserBrokerAgency
  include Interactor

  def call
    return unless broker_role.present?

    context.primary_family.hire_broker_agency(broker_role.id)
    context.shopping_enrollments.each do |hbx_enrollment|
      hbx_enrollment.writing_agent_id = broker_role.id
      hbx_enrollment.broker_agency_profile_id = broker_role.broker_agency_profile_id
    end
  end

  def broker_role
    context.current_user&.person&.broker_role
  end
end