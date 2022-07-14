# frozen_string_literal: true

class PersistEnrollmentAndAssignToAssignments
  include Interactor

  def call
    return unless context.shopping_enrollments.present?
    return unless context.employee_role.present?

    context.shopping_enrollments.each do |enrollment|
      if enrollment.save
        assignment = context.employee_role.census_employee.benefit_group_assignment_by_package(enrollment.sponsored_benefit_package_id, enrollment.effective_on)
        assignment.update(hbx_enrollment_id: enrollment.id)
        enrollment.update(benefit_group_assignment_id: assignment.id)
      else
        context.fail!(message: "failed to save enrollment")
      end
    end
  end
end
