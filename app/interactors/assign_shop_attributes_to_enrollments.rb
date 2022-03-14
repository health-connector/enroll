# frozen_string_literal: true

class AssignShopAttributesToEnrollments
  include Interactor

  def call
    return unless context.market_kind != 'shop' || context.shopping_enrollments.present?

    context.shopping_enrollments.each do |hbx_enrollment|
      keep_existing_plan_attributes(hbx_enrollment) if context.params[:commit] == "Keep existing plan"
      hbx_enrollment.generate_hbx_signature
      hbx_enrollment.original_application_type = context.session_original_application_type
      assign_cobra_attributes(hbx_enrollment) if context.employee_role.is_cobra_status?
    end
  end

  def keep_existing_plan_attributes(hbx_enrollment)
    sep = hbx_enrollment.is_shop? ? hbx_enrollment.family.earliest_effective_shop_sep : hbx_enrollment.family.earliest_effective_ivl_sep
    hbx_enrollment.special_enrollment_period_id = sep.id if sep.present?
  end

  def assign_cobra_attributes(hbx_enrollment)
    census_employee = context.employee_role.census_employee
    hbx_enrollment.kind = 'employer_sponsored_cobra'
    hbx_enrollment.effective_on = census_employee.cobra_begin_date if census_employee.cobra_begin_date > hbx_enrollment.effective_on
  end
end