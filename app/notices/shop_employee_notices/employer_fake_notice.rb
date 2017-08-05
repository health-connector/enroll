class ShopEmployeeNotices::EmployerFakeNotice < ShopEmployeeNotice

  def deliver
    build
    upload_and_send_secure_message
  end

  def build
    pdf = CombinePDF.new
    pdf << CombinePDF.load(Rails.root.join('lib/pdf_templates', 'Denial of Initial Employer Application and Request for Clarifying Documentation.pdf'))
    pdf.save "tmp/ActionRequired:DenialOfApplicationToOfferGroupHealthCoverageThroughTheHealthConnector.pdf"
  end

end