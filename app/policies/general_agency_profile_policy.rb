# frozen_string_literal: true

class GeneralAgencyProfilePolicy < ApplicationPolicy

  def update_staff?
    return false unless user.person
    return true if user.has_hbx_staff_role? || user.has_csr_role? || user.has_broker_role?

    general_agency_profile_id = user.person&.general_agency_staff_roles&.last&.general_agency_profile_id
    user.has_general_agency_staff_role? && general_agency_profile_id.present?
  end
end

