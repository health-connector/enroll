class ShopEmployerNotices::NoticeToEmployerNoBinderPaymentReceived < ShopEmployerNotice

  def deliver
	    build
	    append_data
	    generate_pdf_notice
	    attach_envelope
	    non_discrimination_attachment
	    upload_and_send_secure_message
	    send_generic_notice_alert
  end

  def append_data
    plan_year = employer_profile.show_plan_year
    #plan = plan_year.reference_plan
    notice.plan_year = PdfTemplates::PlanYear.new({
          :start_on => plan_year.start_on
        })
    #binder payment deadline
    notice.plan_year.binder_payment_due_date = PlanYear.calculate_open_enrollment_date(plan_year.start_on)[:binder_payment_due_date]

    notice.plan_year.binder_payment_total = employer_profile.show_plan_year.benefit_groups.last.monthly_employer_contribution_amount

  end
end