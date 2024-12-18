# frozen_string_literal: true

class User
  INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE = "acc"
  MIN_USERNAME_LENGTH = 8
  MAX_USERNAME_LENGTH = 60
  HEX_ESCAPE_REGEX = /\\x([0-9A-Fa-f]{2})/
  EMAIL_REGEX = /\A[^@\s]+@(?>[^@\s]+\.)+[^@\s]+\z/

  include Mongoid::Document
  include Mongoid::Timestamps
  include Acapi::Notifiers
  include AuthorizationConcern
  include Mongoid::History::Trackable
  include PermissionsConcern
  include GlobalID::Identification

  attr_accessor :login, :invitation_id

  validates_presence_of :oim_id
  validates_uniqueness_of :oim_id, :case_sensitive => false
  validate :oim_id_rules
  validates_uniqueness_of :email,:case_sensitive => false
  validate :validate_email_format

  scope :datatable_search, lambda { |query|
    search_regex = ::Regexp.compile(/.*#{query}.*/i)
    person_user_ids = Person.any_of({hbx_id: search_regex}, {first_name: search_regex}, {last_name: search_regex}).pluck(:user_id)
    User.any_of({oim_id: search_regex}, {email: search_regex}, {id: {"$in" => person_user_ids} })
  }

  has_one :person, inverse_of: :user
  accepts_nested_attributes_for :person, allow_destroy: true

  def oim_id_rules
    if oim_id.present? && oim_id.match(%r{[;#%=|+,">< \\/]})
      errors.add :oim_id, "cannot contain special charcters ; # % = | + , \" > < \\ \/"
    elsif oim_id.present? && oim_id.length < MIN_USERNAME_LENGTH
      errors.add :oim_id, "must be at least #{MIN_USERNAME_LENGTH} characters"
    elsif oim_id.present? && oim_id.length > MAX_USERNAME_LENGTH
      errors.add :oim_id, "can NOT exceed #{MAX_USERNAME_LENGTH} characters"
    end
  end

  def valid_attribute?(attribute_name)
    valid?
    errors[attribute_name].blank?
  end

  def switch_to_idp!
    # new_password = self.class.generate_valid_password
    # self.password = new_password
    # self.password_confirmation = new_password
    self.idp_verified = true
    begin
      save!
    rescue StandardError => e
      message = "#{e.message}; "
      message += "user: #{self}, "
      message += "errors.full_messages: #{errors.full_messages}, "
      message += "stacktrace: #{e.backtrace}"
      log(message, {:severity => "error"})
      raise e
    end
  end

  field :hints, type: Mongoid::Boolean, default: true
  # for i18L
  field :preferred_language, type: String, default: "en"

  ## Enable Admin approval
  ## Seed: https://github.com/plataformatec/devise/wiki/How-To%3a-Require-admin-to-activate-account-before-sign_in
  field :approved, type: Mongoid::Boolean, default: true

  # Session token for Devise to prevent concurrent user sessions
  field :current_login_token

  ##RIDP
  field :identity_verified_date, type: Date
  field :identity_final_decision_code, type: String
  field :identity_final_decision_transaction_id, type: String
  field :identity_response_code, type: String
  field :identity_response_description_text, type: String

  ## Trackable
  field :idp_uuid, type: String

  field :roles, :type => Array, :default => []

  # Oracle Identity Manager ID
  field :oim_id, type: String, default: ""

  field :last_portal_visited, type: String
  field :idp_verified, type: Mongoid::Boolean, default: false

  index({preferred_language: 1})
  index({approved: 1})
  index({roles: 1},  {sparse: true}) # MongoDB multikey index
  index({email: 1},  {sparse: true, unique: true})
  index({oim_id: 1}, {sparse: true, unique: true})
  index({created_at: 1 })

  track_history :on => [:oim_id, :email],
                :modifier_field => :modifier,
                :modifier_field_optional => true,
                :version_field => :tracking_version,
                :track_create => true,
                :track_update => true,
                :track_destroy => true

  before_save :strip_empty_fields

  # Enable polymorphic associations
  belongs_to :profile, polymorphic: true, optional: true

  def ensure_valid_invitation
    if invitation_id.blank?
      errors.add(:base, "There is no valid invitation for this account.")
      return
    end
    invitation = Invitation.where(id: invitation_id).first
    unless invitation.present?
      errors.add(:base, "There is no valid invitation for this account.")
      return
    end
    return if invitation.may_claim?

    errors.add(:base, "There is no valid invitation for this account.")
    nil
  end

  def idp_verified?
    idp_verified
  end

  def permission
    person.hbx_staff_role.permission
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_now
    true
  end

  def agent_title
    return unless has_agent_role?

    if has_role?(:assister)
      "In Person Assister (IPA)"
    elsif person&.csr_role&.cac == true
      "Certified Applicant Counselor (CAC)"
    else
      "Customer Service Representative (CSR)"
    end
  end

  def has_tier3_subrole?
    hbx_staff_role = person&.hbx_staff_role
    hbx_staff_role && hbx_staff_role.subrole == "hbx_tier3"
  end

  def is_active_broker?(employer_profile)
    person == employer_profile.active_broker if employer_profile.active_broker
  end

  def is_benefit_sponsor_active_broker?(profile_id)
    profile_organization = BenefitSponsors::Organizations::Organization.employer_profiles.where(:"profiles._id" => BSON::ObjectId.from_string(profile_id)).first
    person == profile_organization&.employer_profile&.active_broker
  end

  def handle_headless_records
    headless_with_email = User.where(email: /^#{::Regexp.quote(email)}$/i)
    headless_with_oim_id = User.where(oim_id: /^#{::Regexp.quote(oim_id)}$/i)
    headless_users = headless_with_email + headless_with_oim_id
    headless_users.each do |headless|
      headless.destroy unless headless.person.present?
    end
  end

  # def password_digest(plaintext_password)
  #     Rypt::Sha512.encrypt(plaintext_password)
  # end
  # # Verifies whether a password (ie from sign in) is the user password.
  # def valid_password?(plaintext_password)
  #   Rypt::Sha512.compare(self.encrypted_password, plaintext_password)
  # end
  def identity_verified?
    return false if identity_final_decision_code.blank?

    identity_final_decision_code.to_s.downcase == INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE
  end

  def ridp_by_payload!
    self.identity_final_decision_code = INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE
    self.identity_response_code = INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE
    self.identity_response_description_text = "curam payload"
    self.identity_verified_date = TimeKeeper.date_of_record
    self.oim_id = email unless oim_id.present?
    save!
  end

  def ridp_by_paper_application
    self.identity_final_decision_code = INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE
    self.identity_response_code = INTERACTIVE_IDENTITY_VERIFICATION_SUCCESS_CODE
    self.identity_response_description_text = "admin bypass ridp"
    self.identity_verified_date = TimeKeeper.date_of_record
    save
  end

  def get_announcements_by_roles_and_portal(portal_path="")
    announcements = []

    case
    when portal_path.include?("employers/employer_profiles")
      announcements.concat(Announcement.current_msg_for_employer) if has_employer_staff_role?
    when portal_path.include?("families/home")
      announcements.concat(Announcement.current_msg_for_employee) if has_employee_role? || (person && person.has_active_employee_role?)
      announcements.concat(Announcement.current_msg_for_ivl) if has_consumer_role? || (person && person.has_active_consumer_role?)
    when portal_path.include?("employee")
      announcements.concat(Announcement.current_msg_for_employee) if has_employee_role? || (person && person.has_active_employee_role?)
    when portal_path.include?("consumer")
      announcements.concat(Announcement.current_msg_for_ivl) if has_consumer_role? || (person && person.has_active_consumer_role?)
    when portal_path.include?("broker_agencies")
      announcements.concat(Announcement.current_msg_for_broker) if has_broker_role?
    when portal_path.include?("general_agencies")
      announcements.concat(Announcement.current_msg_for_ga) if has_general_agency_staff_role?
    end

    announcements.uniq
  end

  def is_active_without_security_question_responses?
    needs_to_provide_security_questions? && person&.primary_family&.enrollments&.detect{|a| a.active_during?(TimeKeeper.date_of_record) }.present?
  end

  class << self
    def find_for_database_authentication(warden_conditions)
      #TODO: Another explicit oim_id dependency
      conditions = warden_conditions.dup
      if (login = conditions.delete(:login).downcase)
        where(conditions).where('$or' => [{:oim_id => /^#{::Regexp.escape(login)}$/i}, {:email => /^#{::Regexp.escape(login)}$/i}]).first
      else
        where(conditions).first
      end
    end

    def by_email(email)
      where(email: /^#{email}$/i).first
    end

    def current_user=(user)
      Thread.current[:current_user] = user
    end

    def get_saml_settings
      settings = OneLogin::RubySaml::Settings.new

      # When disabled, saml validation errors will raise an exception.
      settings.soft = true

      # SP section
      settings.assertion_consumer_service_url = SamlInformation.assertion_consumer_service_url
      settings.assertion_consumer_logout_service_url = SamlInformation.assertion_consumer_logout_service_url
      settings.issuer                         = SamlInformation.issuer

      # IdP section
      settings.idp_entity_id                  = SamlInformation.idp_entity_id
      settings.idp_sso_target_url             = SamlInformation.idp_sso_target_url
      settings.idp_slo_target_url             = SamlInformation.idp_slo_target_url
      settings.idp_cert                       = SamlInformation.idp_cert
      # or settings.idp_cert_fingerprint           = "3B:05:BE:0A:EC:84:CC:D4:75:97:B3:A2:22:AC:56:21:44:EF:59:E6"
      #    settings.idp_cert_fingerprint_algorithm = XMLSecurity::Document::SHA1

      settings.name_identifier_format         = SamlInformation.name_identifier_format

      # Security section
      settings.security[:authn_requests_signed] = false
      settings.security[:logout_requests_signed] = false
      settings.security[:logout_responses_signed] = false
      settings.security[:metadata_signed] = false
      settings.security[:digest_method] = XMLSecurity::Document::SHA1
      settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA1

      settings
    end

    # Instances without a matching Person model
    # This suboptimal query approach is necessary, as the belongs_to side of the association holds the
    #   ID in a has_one association
    def orphans
      user_ids = Person.where(:user_id => { "$ne" => nil }).pluck(:user_id)
      User.where("_id" => { "$nin" => user_ids }).order(email: :asc).entries
    end
  end

  private

  # Remove indexed, unique, empty attributes from document
  def strip_empty_fields
    unset("email") if email.blank?
    unset("oim_id") if oim_id.blank?
  end

  def validate_email_format
    return unless email.present?

    errors.add(:email, "is invalid") unless email.match?(EMAIL_REGEX)
    errors.add(:email, "contains invalid characters") if email.match?(HEX_ESCAPE_REGEX)
  end

end
