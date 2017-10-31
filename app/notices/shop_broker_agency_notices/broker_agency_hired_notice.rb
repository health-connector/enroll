class ShopBrokerAgencyNotices::BrokerAgencyHiredNotice < ShopBrokerAgencyNotice

  def initialize(employer_profile, args = {})
    self.employer_profile = employer_profile
    self.broker_agency_profile = employer_profile.broker_agency_profile
    args[:recipient] = broker_agency_profile
    args[:market_kind]= 'shop'
    args[:notice] = PdfTemplates::BrokerNotice.new
    args[:to] = broker_agency_profile.primary_broker_role.email_address
    args[:name] = broker_agency_profile.primary_broker_role.person.full_name
    args[:recipient_document_store] = broker_agency_profile
    self.header = "notices/shared/header_with_page_numbers.html.erb"
    super(args)
  end

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
    notice.assignment_date = employer_profile.broker_agency_accounts.detect{|br| br.is_active == true}.start_on
  end
end