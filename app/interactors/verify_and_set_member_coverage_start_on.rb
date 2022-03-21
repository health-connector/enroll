# frozen_string_literal: true

class VerifyAndSetMemberCoverageStartOn
  include Interactor

  def call
    return unless parent_enrollment.present? && (parent_enrollment.product_id == context.product.id)

    previous_enrollment_members = parent_enrollment.hbx_enrollment_members

    hbx_enrollment.hbx_enrollment_members.each do |member|
      matched = previous_enrollment_members.detect{|enrollment_member| enrollment_member.hbx_id == member.hbx_id}
      member.coverage_start_on = matched.coverage_start_on || parent_enrollment.effective_on if matched
    end
  end

  def hbx_enrollment
    @hbx_enrollment ||= context.hbx_enrollment
  end

  def parent_enrollment
    @parent_enrollment ||= hbx_enrollment.parent_enrollment
  end
end