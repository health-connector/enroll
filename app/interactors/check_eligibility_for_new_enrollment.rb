# frozen_string_literal: true

class CheckEligibilityForNewEnrollment
  include Interactor

  def call
    if context.census_employee.present?
      new_hire_enrollment_period = context.census_employee.new_hire_enrollment_period
      if new_hire_enrollment_period.begin > TimeKeeper.date_of_record
        context.fail!(message: "You're not yet eligible under your employer-sponsored benefits. Please return on #{new_hire_enrollment_period.begin.strftime('%m/%d/%Y')} to enroll for coverage.")
      end
    end

    return unless context.params[:is_waiving].blank?

    context.fail!(message: "You must select at least one Eligible applicant to enroll in the healthcare plan") if context.params[:family_member_ids].blank?
    context.params.require(:family_member_ids).collect do |_index, family_member_id|
      BSON::ObjectId.from_string(family_member_id)
    end
  end
end