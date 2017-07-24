class ShopEmployerNotices::RenewalEmployerIneligibilityNotice < ShopEmployerNotice

  def deliver
    build
    append_data
    generate_pdf_notice
    attach_envelope
    employer_appeal_rights_attachment
    non_discrimination_attachment
    upload_and_send_secure_message
    send_generic_notice_alert
  end

  def append_data
    renewing_plan_year = employer_profile.plan_years.where(:aasm_state => "application_ineligible").first
    active_plan_year = employer_profile.plan_years.where(:aasm_state => "active").first

    plan_year_warnings = []
    if renewing_plan_year
    renewing_plan_year.enrollment_errors.each do |k, v|
      case k.to_s
      when "enrollment_ratio"
        plan_year_warnings << "At least 75% of your eligible employees enrolled in your group health coverage or waive due to having other coverage."
      when "non_business_owner_enrollment_count"
        plan_year_warnings << "One non-owner employee enrolled in health coverage"
      end
    end
  end

    notice.plan_year = PdfTemplates::PlanYear.new({
        :start_on => renewing_plan_year.start_on,
        :open_enrollment_end_on => renewing_plan_year.open_enrollment_end_on,
        :end_on => 12/20/2017,
        :warnings => plan_year_warnings
      })
  end

end