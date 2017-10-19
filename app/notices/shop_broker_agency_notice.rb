class ShopBrokerAgencyNotice < Notice
  Required= Notice::Required + []

  attr_accessor :broker_agency_profile
  attr_accessor :employer_profile

  def initialize(options ={})
    super
  end

  def build
    notice.mpi_indicator = self.mpi_indicator
    notice.primary_fullname = broker_agency_profile.legal_name
    notice.employer_name = employer_profile.legal_name.titleize
    notice.employer_first_name = employer_profile.staff_roles.first.first_name.titleize
    notice.employer_last_name = employer_profile.staff_roles.first.last_name.titleize
    notice.broker_agency = broker_agency_profile.legal_name.titleize
    notice.email = employer_profile.staff_roles.first.work_email_or_best
    notice.phone = broker_agency_profile.phone
    append_address(broker_agency_profile.organization.primary_office_location.address)
  end

  def attach_envelope
    join_pdfs [notice_path, Rails.root.join('lib/pdf_templates', 'ma_envelope_without_address.pdf')]
  end

  def non_discrimination_attachment
    join_pdfs [notice_path, Rails.root.join('lib/pdf_templates', 'ma_shop_non_discrimination_attachment.pdf')]
  end

  def employer_appeal_rights_attachment
    join_pdfs [notice_path, Rails.root.join('lib/pdf_templates', 'ma_employer_appeal_rights.pdf')]
  end

  def append_address(primary_address)
    notice.primary_address = PdfTemplates::NoticeAddress.new({
                                 street_1: primary_address.address_1.titleize,
                                 street_2: primary_address.address_2.titleize,
                                 city: primary_address.city.titleize,
                                 state: primary_address.state,
                                 zip: primary_address.zip
                             })
  end

end