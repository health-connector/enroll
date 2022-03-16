# frozen_string_literal: true

class VerifyAndSetMemberCoverageStartOn
  include Interactor

  def call
    if hbx_enrollment.parent_enrollment.present? && (hbx_enrollment.parent_enrollment.product_id == context.product.id)
      previous_enrollment_members = hbx_enrollment.parent_enrollment.hbx_enrollment_members

      hbx_enrollment.hbx_enrollment_members.each do |member|
        matched = previous_enrollment_members.detect{|enrollment_member| enrollment_member.hbx_id == member.hbx_id}

        if matched
          member.coverage_start_on = matched.coverage_start_on || hbx_enrollment.parent_enrollment.effective_on
        end
      end
    end

  end

  def hbx_enrollment
    context.hbx_enrollment
  end
end