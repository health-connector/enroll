# frozen_string_literal: true

class CheckEmployerBenefitsForEmployee
  include Interactor

  def call
    return unless context.market_kind != 'shop' || context.shopping_enrollments.present?

    context.shopping_enrollments.each do |hbx_enrollment|
      unless hbx_enrollment.sponsored_benefit_package.shoppable?
        if hbx_enrollment.sponsored_benefit_package.benefit_application.terminated?
          context.fail!(message: "Your employer is no longer offering #{hbx_enrollment.coverage_kind} insurance through #{Settings.site.short_name}. Please contact your employer.")
        elsif hbx_enrollment.sponsored_benefit_package.benefit_application.termination_pending?
          context.fail!(message: "Your employer is no longer offering #{hbx_enrollment.coverage_kind} insurance through #{Settings.site.short_name}.
                                  Please contact your employer or call our Customer Care Center at #{Settings.contact_center.phone_number}.")
        else
          context.fail!(message: "Open enrollment for your employer-sponsored benefits not yet started. Please return on #{hbx_enrollment.sponsored_benefit_package.open_enrollment_start_on.strftime('%m/%d/%Y')} to enroll for coverage.")
        end
      end
    end
  end
end