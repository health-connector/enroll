# frozen_string_literal: true

class Person
  include Config::AcaModelConcern
  include Config::SiteModelConcern
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  # include Mongoid::Versioning
  include Mongoid::Attributes::Dynamic
  include SponsoredBenefits::Concerns::Ssn
  include SponsoredBenefits::Concerns::Dob

  include Notify
  include UnsetableSparseFields
  include FullStrippedNames
  include ::BenefitSponsors::Concerns::Observable

  # verification history tracking
  include Mongoid::History::Trackable

  track_history :on => [:first_name,
                        :middle_name,
                        :last_name,
                        :full_name,
                        :alternate_name,
                        :encrypted_ssn,
                        :dob,
                        :gender,
                        :is_incarcerated,
                        :is_disabled,
                        :ethnicity,
                        :race,
                        :tribal_id,
                        :no_dc_address,
                        :no_dc_address_reason,
                        :is_active,
                        :no_ssn],
                :modifier_field => :modifier,
                :modifier_field_optional => true,
                :version_field => :tracking_version,
                :track_create => true,    # track document creation, default is false
                :track_update => true,    # track document updates, default is true
                :track_destroy => true     # track document destruction, default is false


  extend Mongorder
#  validates_with Validations::DateRangeValidator

  GENDER_KINDS = %w[male female].freeze

  IDENTIFYING_INFO_ATTRIBUTES = %w[first_name last_name ssn dob].freeze
  ADDRESS_CHANGE_ATTRIBUTES = %w[addresses phones emails].freeze
  RELATIONSHIP_CHANGE_ATTRIBUTES = %w[person_relationships].freeze

  PERSON_CREATED_EVENT_NAME = "acapi.info.events.individual.created"
  PERSON_UPDATED_EVENT_NAME = "acapi.info.events.individual.updated"
  VERIFICATION_TYPES = ['Social Security Number', 'American Indian Status', 'Citizenship', 'Immigration status'].freeze

  field :hbx_id, type: String
  field :name_pfx, type: String
  field :first_name, type: String
  field :middle_name, type: String
  field :last_name, type: String
  field :name_sfx, type: String
  field :full_name, type: String
  field :alternate_name, type: String

  field :encrypted_ssn, type: String
  field :gender, type: String
  field :dob, type: Date

  # Sub-model in-common attributes
  field :date_of_death, type: Date
  field :dob_check, type: Mongoid::Boolean

  field :is_incarcerated, type: Mongoid::Boolean

  field :is_disabled, type: Mongoid::Boolean
  field :ethnicity, type: Array
  field :race, type: String
  field :tribal_id, type: String

  field :is_tobacco_user, type: String, default: "unknown"
  field :language_code, type: String

  field :no_dc_address, type: Mongoid::Boolean, default: false
  field :no_dc_address_reason, type: String, default: ""

  field :is_active, type: Mongoid::Boolean, default: true
  field :updated_by, type: String
  field :no_ssn, type: String #ConsumerRole TODO TODOJF
  field :is_physically_disabled, type: Mongoid::Boolean

  delegate :is_applying_coverage, to: :consumer_role, allow_nil: true

  # Login account
  belongs_to :user, inverse_of: :person, optional: true

  belongs_to :employer_contact,
             class_name: "EmployerProfile",
             inverse_of: :employer_contacts,
             index: true,
             optional: true

  belongs_to :broker_agency_contact,
             class_name: "BrokerAgencyProfile",
             inverse_of: :broker_agency_contacts,
             index: true,
             optional: true

  belongs_to :general_agency_contact,
             class_name: "GeneralAgencyProfile",
             inverse_of: :general_agency_contacts,
             index: true,
             optional: true

  embeds_one :consumer_role, cascade_callbacks: true, validate: true
  embeds_one :resident_role, cascade_callbacks: true, validate: true
  embeds_one :broker_role, cascade_callbacks: true, validate: true
  embeds_one :hbx_staff_role, cascade_callbacks: true, validate: true
  #embeds_one :responsible_party, cascade_callbacks: true, validate: true # This model does not exist.

  embeds_one :csr_role, cascade_callbacks: true, validate: true
  embeds_one :assister_role, cascade_callbacks: true, validate: true
  embeds_one :inbox, as: :recipient

  embeds_many :employer_staff_roles, cascade_callbacks: true, validate: true
  embeds_many :broker_agency_staff_roles, cascade_callbacks: true, validate: true
  embeds_many :employee_roles, cascade_callbacks: true, validate: true
  embeds_many :general_agency_staff_roles, cascade_callbacks: true, validate: true

  embeds_many :person_relationships, cascade_callbacks: true, validate: true
  embeds_many :addresses, cascade_callbacks: true, validate: true
  embeds_many :phones, cascade_callbacks: true, validate: true
  embeds_many :emails, cascade_callbacks: true, validate: true
  embeds_many :documents, as: :documentable

  accepts_nested_attributes_for :consumer_role, :resident_role, :broker_role, :hbx_staff_role,
                                :person_relationships, :employee_roles, :phones, :employer_staff_roles

  accepts_nested_attributes_for :phones, :reject_if => proc { |addy| addy[:full_phone_number].blank? }, allow_destroy: true
  accepts_nested_attributes_for :addresses, :reject_if => proc { |addy| addy[:address_1].blank? && addy[:city].blank? && addy[:state].blank? && addy[:zip].blank? }, allow_destroy: true
  accepts_nested_attributes_for :emails, :reject_if => proc { |addy| addy[:address].blank? }, allow_destroy: true

  validate :date_functional_validations
  validate :no_changing_my_user, :on => :update

  validates :first_name, :last_name, presence: true

  validates :encrypted_ssn, uniqueness: true, allow_blank: true

  validates :gender,
            allow_blank: true,
            inclusion: { in: Person::GENDER_KINDS, message: "%<value>s is not a valid gender" }

  before_save :generate_hbx_id
  before_save :update_full_name
  before_save :strip_empty_fields

  #after_save :generate_family_search
  after_create :create_inbox

  add_observer ::BenefitSponsors::Observers::EmployerStaffRoleObserver.new, :contact_changed?

  index({hbx_id: 1}, {sparse: true, unique: true})
  index({user_id: 1}, {sparse: true, unique: true})

  index({last_name:  1})
  index({first_name: 1})
  index({last_name: 1, first_name: 1})
  index({first_name: 1, last_name: 1})
  index({first_name: 1, last_name: 1, hbx_id: 1, encrypted_ssn: 1}, {name: "person_searching_index"})

  index({encrypted_ssn: 1}, {sparse: true, unique: true})
  index({dob: 1}, {sparse: true})
  index({dob: 1, encrypted_ssn: 1})

  index({last_name: 1, dob: 1}, {sparse: true})
  index({last_name: "text", first_name: "text", full_name: "text"}, {name: "person_search_text_index"})

  # Broker child model indexes
  index({"broker_role._id" => 1})
  index({"broker_role.provider_kind" => 1})
  index({"broker_role.broker_agency_id" => 1})
  index({"broker_role.npn" => 1}, {sparse: true, unique: true})

  # Employer role index
  index({"employer_staff_roles._id" => 1})
  index({"employer_staff_roles.employer_profile_id" => 1})

  # Consumer child model indexes
  index({"consumer_role._id" => 1})
  index({"consumer_role.aasm_state" => 1})
  index({"consumer_role.is_active" => 1})

  # Employee child model indexes
  index({"employee_roles._id" => 1})
  index({"employee_roles.employer_profile_id" => 1})
  index({"employee_roles.census_employee_id" => 1})
  index({"employee_roles.benefit_group_id" => 1})
  index({"employee_roles.is_active" => 1})

  # HbxStaff child model indexes
  index({"hbx_staff_role._id" => 1})
  index({"hbx_staff_role.is_active" => 1})

  # PersonRelationship child model indexes
  index({"person_relationship.relative_id" =>  1})

  index({"hbx_employer_staff_role._id" => 1})

  #index({"hbx_responsible_party_role._id" => 1})

  index({"hbx_csr_role._id" => 1})
  index({"hbx_assister._id" => 1})

  scope :all_consumer_roles,          -> { exists(consumer_role: true) }
  scope :all_resident_roles,          -> { exists(resident_role: true) }
  scope :all_employee_roles,          -> { exists(employee_roles: true) }
  scope :all_employer_staff_roles,    -> { exists(employer_staff_roles: true) }

  #scope :all_responsible_party_roles, -> { exists(responsible_party_role: true) }
  scope :all_broker_roles,            -> { exists(broker_role: true) }
  scope :all_hbx_staff_roles,         -> { exists(hbx_staff_role: true) }
  scope :all_csr_roles,               -> { exists(csr_role: true) }
  scope :all_assister_roles,          -> { exists(assister_role: true) }

  scope :by_hbx_id, ->(person_hbx_id) { where(hbx_id: person_hbx_id) }
  scope :by_broker_role_npn, ->(br_npn) { where("broker_role.npn" => br_npn) }
  scope :active,   ->{ where(is_active: true) }
  scope :inactive, ->{ where(is_active: false) }

  #scope :broker_role_having_agency, -> { where("broker_role.broker_agency_profile_id" => { "$ne" => nil }) }
  scope :broker_role_having_agency, -> { where("broker_role.benefit_sponsors_broker_agency_profile_id" => { "$ne" => nil }) }
  scope :broker_role_applicant,     -> { where("broker_role.aasm_state" => { "$eq" => :applicant })}
  scope :broker_role_pending,       -> { where("broker_role.aasm_state" => { "$eq" => :broker_agency_pending })}
  scope :broker_role_certified,     -> { where("broker_role.aasm_state" => { "$in" => [:active]})}
  scope :broker_role_decertified,   -> { where("broker_role.aasm_state" => { "$eq" => :decertified })}
  scope :broker_role_denied,        -> { where("broker_role.aasm_state" => { "$eq" => :denied })}
  scope :by_ssn,                    ->(ssn) { where(encrypted_ssn: Person.encrypt_ssn(ssn)) }
  scope :unverified_persons,        -> { where(:'consumer_role.aasm_state' => { "$ne" => "fully_verified" })}
  scope :matchable,                 ->(ssn, dob, last_name) { where(encrypted_ssn: Person.encrypt_ssn(ssn), dob: dob, last_name: last_name) }

  scope :general_agency_staff_applicant,     -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :applicant })}
  scope :general_agency_staff_certified,     -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :active })}
  scope :general_agency_staff_decertified,   -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :decertified })}
  scope :general_agency_staff_denied,        -> { where("general_agency_staff_roles.aasm_state" => { "$eq" => :denied })}
#  ViewFunctions::Person.install_queries

  validate :consumer_fields_validations

  after_create :notify_created
  after_update :notify_updated, if: :attributes_changed?

  def active_general_agency_staff_roles
    general_agency_staff_roles.select(&:active?)
  end

  def contact_addresses
    existing_addresses = addresses.to_a
    home_address = existing_addresses.detect { |addy| addy.kind == "home" }
    return existing_addresses if home_address

    add_employee_home_address(existing_addresses)
  end

  def add_employee_home_address(existing_addresses)
    return existing_addresses unless employee_roles.any?

    employee_contact_address = employee_roles.sort_by(&:hired_on).map(&:census_employee).compact.map(&:address).compact.first
    return existing_addresses unless employee_contact_address

    existing_addresses + [employee_contact_address]
  end

  def contact_phones
    phones.reject { |ph| ph.full_phone_number.blank? }
  end

  delegate :citizen_status, :citizen_status=, :to => :consumer_role, :allow_nil => true
  delegate :ivl_coverage_selected, :to => :consumer_role, :allow_nil => true
  delegate :all_types_verified?, :to => :consumer_role

  def notify_created
    notify(PERSON_CREATED_EVENT_NAME, {:individual_id => hbx_id })
  end

  def notify_updated
    Rails.logger.info "person update event is getting triggered"
    notify(PERSON_UPDATED_EVENT_NAME, {:individual_id => hbx_id })
  end

  def is_aqhp?
    family = primary_family if primary_family
    if family
      check_households(family) && check_tax_households(family)
    else
      false
    end
  end

  def check_households(family)
    family.households.present?
  end

  def check_tax_households(family)
    family.households.first.tax_households.present?
  end

  def completed_identity_verification?
    return false unless user

    user.identity_verified?
  end

  #after_save :update_family_search_collection

  # before_save :notify_change
  # def notify_change
  #   notify_change_event(self, {"identifying_info"=>IDENTIFYING_INFO_ATTRIBUTES, "address_change"=>ADDRESS_CHANGE_ATTRIBUTES, "relation_change"=>RELATIONSHIP_CHANGE_ATTRIBUTES})
  # end

  def update_family_search_collection
    #  ViewFunctions::Person.run_after_save_search_update(self.id)
  end

  def generate_hbx_id
    write_attribute(:hbx_id, HbxIdGenerator.generate_member_id) if hbx_id.blank?
  end

  def strip_empty_fields
    unset_sparse("encrypted_ssn") if encrypted_ssn.blank?

    return unless user_id.blank?

    unset_sparse("user_id")
  end

  def date_of_birth=(val)
    self.dob = begin
      Date.strptime(val, "%m/%d/%Y").to_date
    rescue StandardError => e
      Rails.logger.error(e)
      nil
    end
  end

  def gender=(new_gender)
    write_attribute(:gender, new_gender.to_s.downcase)
  end

  # Get the {Family} where this {Person} is the primary family member
  #
  # family itegrity ensures only one active family can be the primary for a person
  #
  # @return [ Family ] the family member who matches this person
  def primary_family
    @primary_family ||= Family.find_primary_applicant_by_person(self).first
  end

  def families
    Family.find_all_by_person(self)
  end

  def full_name
    @full_name = [name_pfx, first_name, middle_name, last_name, name_sfx].compact.join(" ")
  end

  def first_name_last_name_and_suffix
    [first_name, last_name, name_sfx].compact.join(" ")
    case name_sfx
    when "ii" || "iii" || "iv" || "v"
      [first_name.capitalize, last_name.capitalize, name_sfx.upcase].compact.join(" ")
    else
      [first_name.capitalize, last_name.capitalize, name_sfx].compact.join(" ")
    end
  end

  def is_active?
    is_active
  end

  def update_ssn_and_gender_for_employer_role(census_employee)
    return if census_employee.blank?

    update_attributes(ssn: census_employee.ssn) if ssn.blank?
    update_attributes(gender: census_employee.gender) if gender.blank?
  end

  # collect all verification types user can have based on information he provided
  def verification_types
    verification_types = []
    verification_types << 'DC Residency'
    verification_types << 'Social Security Number' if ssn
    verification_types << 'American Indian Status' unless tribal_id.nil? || tribal_id.empty?
    verification_types << if us_citizen
                            'Citizenship'
                          else
                            'Immigration status'
                          end
    verification_types
  end

  def relatives
    person_relationships.reject do |p_rel|
      p_rel.relative_id.to_s == id.to_s
    end.map(&:relative)
  end

  def find_relationship_with(other_person)
    if id == other_person.id
      "self"
    else
      person_relationship_for(other_person).try(:kind)
    end
  end

  def person_relationship_for(other_person)
    person_relationships.detect do |person_relationship|
      person_relationship.relative_id == other_person.id
    end
  end

  def ensure_relationship_with(person, relationship)
    return if person.blank?

    existing_relationship = person_relationships.detect do |rel|
      rel.relative_id.to_s == person.id.to_s
    end
    if existing_relationship
      existing_relationship.assign_attributes(:kind => relationship)
      update_census_dependent_relationship(existing_relationship)
      existing_relationship.save!
    else
      person_relationships << PersonRelationship.new({
                                                       :kind => relationship,
                                                       :relative_id => person.id
                                                     })
    end
  end

  def add_work_email(email)
    existing_email = emails.detect do |e|
      (e.kind == 'work') &&
        (e.address.downcase == email.downcase)
    end
    return nil if existing_email.present?

    emails << ::Email.new(:kind => 'work', :address => email)
  end

  def home_address
    addresses.detect { |adr| adr.kind == "home" }
  end

  def mailing_address
    addresses.detect { |adr| adr.kind == "mailing" } || home_address
  end

  def has_mailing_address?
    addresses.any? { |adr| adr.kind == "mailing" }
  end

  def home_email
    emails.detect { |adr| adr.kind == "home" }
  end

  def work_email
    emails.detect { |adr| adr.kind == "work" }
  end

  def work_or_home_email
    work_email || home_email
  end

  def work_email_or_best
    email = emails.detect { |adr| adr.kind == "work" } || emails.first
    email&.address || user&.email
  end

  def work_phone
    phones.detect { |phone| phone.kind == "work" } || main_phone
  end

  def main_phone
    phones.detect { |phone| phone.kind == "main" }
  end

  def home_phone
    phones.detect { |phone| phone.kind == "home" }
  end

  def mobile_phone
    phones.detect { |phone| phone.kind == "mobile" }
  end

  def work_phone_or_best
    best_phone  = work_phone || mobile_phone || home_phone
    best_phone ? best_phone.full_phone_number : nil
  end

  def has_active_consumer_role?
    consumer_role.present? and consumer_role.is_active?
  end

  def has_active_resident_role?
    resident_role.present? and resident_role.is_active?
  end

  def can_report_shop_qle?
    employee_roles.first.census_employee.qle_30_day_eligible?
  end

  def has_active_employee_role?
    active_employee_roles.any?
  end

  def has_active_shopping_role?
    has_active_employee_role? ||
      has_active_resident_role? ||
      has_active_consumer_role?
  end

  def has_employer_benefits?
    active_employee_roles.present? #&& active_employee_roles.any?{|r| r.benefit_group.present?}
  end

  def active_employee_roles
    employee_roles.select{|employee_role| employee_role.census_employee&.is_active? }
  end

  def has_multiple_active_employers?
    active_employee_roles.count > 1
  end

  def has_active_employer_staff_role?
    employer_staff_roles.present? and employer_staff_roles.active.present?
  end

  def active_employer_staff_roles
    employer_staff_roles.present? ? employer_staff_roles.active : []
  end

  def has_multiple_roles?
    consumer_role.present? && active_employee_roles.present?
  end

  def has_active_employee_role_for_census_employee?(census_employee)
    return unless census_employee

    (active_employee_roles.detect { |employee_role| employee_role.census_employee == census_employee }).present?
  end

  def residency_eligible?
    no_dc_address and no_dc_address_reason.present?
  end

  def is_dc_resident?
    return false if no_dc_address == true && no_dc_address_reason.blank?
    return true if no_dc_address == true && no_dc_address_reason.present?

    address_to_use = addresses.collect(&:kind).include?('home') ? 'home' : 'mailing'
    addresses.each{|address| return true if address.kind == address_to_use && address.state == aca_state_abbreviation}
    false
  end

  class << self
    def default_search_order
      [[:last_name, 1],[:first_name, 1]]
    end

    def search_hash(s_str)
      clean_str = s_str.strip
      s_rex = ::Regexp.new(::Regexp.escape(clean_str), true)
      {
        "$or" => ([
          {"first_name" => s_rex},
          {"last_name" => s_rex},
          {"hbx_id" => s_rex},
          {"encrypted_ssn" => encrypt_ssn(s_rex)}
        ] + additional_exprs(clean_str))
      }
    end

    def additional_exprs(clean_str)
      additional_exprs = []
      if clean_str.include?(" ")
        parts = clean_str.split.compact
        first_re = ::Regexp.new(::Regexp.escape(parts.first), true)
        last_re = ::Regexp.new(::Regexp.escape(parts.last), true)
        additional_exprs << {:first_name => first_re, :last_name => last_re}
      end
      additional_exprs
    end

    def search_first_name_last_name_npn(s_str, query = self)
      clean_str = s_str.strip
      s_rex = ::Regexp.new(::Regexp.escape(s_str.strip), true)
      query.where({
                    "$or" => ([
                      {"first_name" => s_rex},
                      {"last_name" => s_rex},
                      {"broker_role.npn" => s_rex}
                      ] + additional_exprs(clean_str))
                  })
    end

    # Find all employee_roles.  Since person has_many employee_roles, person may show up
    # employee_role.person may not be unique in returned set
    def employee_roles
      people = exists(:'employee_roles.0' => true).entries
      people.flat_map(&:employee_roles)
    end

    def find_all_brokers_or_staff_members_by_agency(broker_agency)
      Person.or({:"broker_role.broker_agency_profile_id" => broker_agency.id},
                {:"broker_agency_staff_roles.broker_agency_profile_id" => broker_agency.id})
    end

    def sans_primary_broker(broker_agency)
      where(:"broker_role._id".nin => [broker_agency.primary_broker_role_id])
    end

    def find_all_staff_roles_by_employer_profile(employer_profile)
      #where({"$and"=>[{"employer_staff_roles.employer_profile_id"=> employer_profile.id}, {"employer_staff_roles.is_owner"=>true}]})
      staff_for_employer(employer_profile)
    end

    def match_existing_person(personish)
      return nil if personish.ssn.blank?

      Person.where(:encrypted_ssn => encrypt_ssn(personish.ssn), :dob => personish.dob).first
    end

    def person_has_an_active_enrollment?(person)
      if !person.primary_family.blank? && !person.primary_family.enrollments.blank?
        person.primary_family.enrollments.each do |enrollment|
          return true if enrollment.is_active
        end
      end
      false
    end

    def dob_change_implication_on_active_enrollments(person, new_dob)
      # This method checks if there is a premium implication in all active enrollments when a persons DOB is changed.
      # Returns a hash with Key => HbxEnrollment ID and, Value => true if  enrollment has Premium Implication.
      premium_impication_for_enrollment = {}
      active_enrolled_hbxs = person.primary_family.active_household.hbx_enrollments.active.enrolled_and_renewal

      # Iterate over each enrollment and check if there is a Premium Implication based on the following rule:
      # Rule: There are Implications when DOB changes makes anyone in the household a different age on the day coverage started UNLESS the
      #       change is all within the 0-20 age range or all within the 61+ age range (20 >= age <= 61)
      active_enrolled_hbxs.each do |hbx|
        new_temp_person = person.dup
        new_temp_person.dob = Date.strptime(new_dob.to_s, '%m/%d/%Y')
        new_age     = new_temp_person.age_on(hbx.effective_on)  # age with the new DOB on the day coverage started
        current_age = person.age_on(hbx.effective_on)           # age with the current DOB on the day coverage started

        next if new_age == current_age # No Change in age -> No Premium Implication

        # No Implication when the change is all within the 0-20 age range or all within the 61+ age range
        if (current_age.between?(0,20) && new_age.between?(0,20)) || (current_age >= 61 && new_age >= 61)
          #premium_impication_for_enrollment[hbx.id] = false
        else
          premium_impication_for_enrollment[hbx.id] = true
        end
      end
      premium_impication_for_enrollment
    end

    # Return an instance list of active People who match identifying information criteria
    def match_by_id_info(options)
      ssn_query = options[:ssn]
      dob_query = options[:dob]
      last_name = options[:last_name]
      first_name = options[:first_name]

      raise ArgumentError, "must provide an ssn or first_name/last_name/dob or both" if ssn_query.blank? && (dob_query.blank? || last_name.blank? || first_name.blank?)

      matches = []
      matches.concat Person.active.where(encrypted_ssn: encrypt_ssn(ssn_query), dob: dob_query).to_a unless ssn_query.blank?
      #matches.concat Person.where(last_name: last_name, dob: dob_query).active.to_a unless (dob_query.blank? || last_name.blank?)
      if first_name.present? && last_name.present? && dob_query.present?
        first_exp = /^#{first_name}$/i
        last_exp = /^#{last_name}$/i
        matches.concat Person.active.where(dob: dob_query, last_name: last_exp, first_name: first_exp).to_a.select{|person| person.ssn.blank? || ssn_query.blank?}
      end
      matches.uniq
    end

    def brokers_or_agency_staff_with_status(query, status)
      query.and(
        Person.or(
          { :"broker_agency_staff_roles.aasm_state" => status },
          { :"broker_role.aasm_state" => status }
        ).selector
      )
    end

    def staff_for_employer(employer_profile)
      if employer_profile.is_a?(EmployerProfile)
        where(:employer_staff_roles => {
                '$elemMatch' => {
                  employer_profile_id: employer_profile.id,
                  aasm_state: :is_active
                }
              }).to_a
      else
        where(:employer_staff_roles => {
                '$elemMatch' => {
                  benefit_sponsor_employer_profile_id: employer_profile.id,
                  aasm_state: :is_active
                }
              }).to_a
      end
    end

    def staff_for_employer_including_pending(employer_profile)
      if employer_profile.is_a?(EmployerProfile)
        where(:employer_staff_roles => {
                '$elemMatch' => {
                  employer_profile_id: employer_profile.id,
                  :aasm_state.ne => :is_closed
                }
              })
      else
        where(:employer_staff_roles => {
                '$elemMatch' => {
                  benefit_sponsor_employer_profile_id: employer_profile.id,
                  :aasm_state.ne => :is_closed
                }
              })
      end
    end

    # Adds employer staff role to person
    # Returns status and message if failed
    # Returns status and person if successful
    def add_employer_staff_role(first_name, last_name, dob, email, employer_profile)
      escaped_first_name = Regexp.escape(first_name)
      escaped_last_name = Regexp.escape(last_name)

      person = Person.where(
        first_name: /\A#{escaped_first_name}\z/i,
        last_name: /\A#{escaped_last_name}\z/i,
        dob: dob
      )

      return false, 'Person count too high, please contact HBX Admin' if person.count > 1
      return false, 'Person does not exist on the HBX Exchange' if person.count == 0

      employer_staff_role = if employer_profile.is_a?(EmployerProfile)
                              EmployerStaffRole.create(person: person.first, employer_profile_id: employer_profile._id)
                            else
                              EmployerStaffRole.create(person: person.first, benefit_sponsor_employer_profile_id: employer_profile._id)
                            end

      employer_staff_role.save

      [true, person.first]
    end

    # Sets employer staff role to inactive
    # Returns false if person not found
    # Returns false if employer staff role not matches
    # Returns true is role was marked inactive
    def deactivate_employer_staff_role(person_id, employer_profile_id)
      begin
        person = Person.find(person_id)
      rescue StandardError
        return false, 'Person not found'
      end
      if (role = person.employer_staff_roles.detect{|rle| (rle.benefit_sponsor_employer_profile_id.to_s == employer_profile_id.to_s || rle.employer_profile_id.to_s == employer_profile_id.to_s) && !rle.is_closed?})
        role.update_attributes!(:aasm_state => :is_closed)
        [true, 'Employee Staff Role is inactive']
      else
        [false, 'No matching employer staff role']
      end
    end

  end

  # HACK
  # FIXME
  # TODO: Move this out of here
  attr_writer :us_citizen, :naturalized_citizen, :indian_tribe_member, :eligible_immigration_status

  attr_accessor :is_consumer_role, :is_resident_role

  before_save :assign_citizen_status_from_consumer_role

  def assign_citizen_status_from_consumer_role
    return unless is_consumer_role.to_s == "true"

    assign_citizen_status
  end

  def us_citizen=(val)
    @us_citizen = (val.to_s == "true")
    @naturalized_citizen = false if val.to_s == "false"
  end

  def naturalized_citizen=(val)
    @naturalized_citizen = (val.to_s == "true")
  end

  def indian_tribe_member=(val)
    self.tribal_id = nil if val.to_s == false
    @indian_tribe_member = (val.to_s == "true")
  end

  def eligible_immigration_status=(val)
    @eligible_immigration_status = (val.to_s == "true")
  end

  def us_citizen
    return @us_citizen unless @us_citizen.nil?
    return nil if citizen_status.blank?

    @us_citizen ||= ::ConsumerRole::US_CITIZEN_STATUS_KINDS.include?(citizen_status)
  end

  def naturalized_citizen
    return @naturalized_citizen unless @naturalized_citizen.nil?
    return nil if citizen_status.blank?

    @naturalized_citizen ||= (::ConsumerRole::NATURALIZED_CITIZEN_STATUS == citizen_status)
  end

  def indian_tribe_member
    return @indian_tribe_member unless @indian_tribe_member.nil?
    return nil if citizen_status.blank?

    @indian_tribe_member ||= !(tribal_id.nil? || tribal_id.empty?)
  end

  def eligible_immigration_status
    return @eligible_immigration_status unless @eligible_immigration_status.nil?
    return nil if us_citizen.nil?
    return nil if @us_citizen
    return nil if citizen_status.blank?

    @eligible_immigration_status ||= (::ConsumerRole::ALIEN_LAWFULLY_PRESENT_STATUS == citizen_status)
  end

  def assign_citizen_status
    new_status = nil
    if naturalized_citizen
      new_status = ::ConsumerRole::NATURALIZED_CITIZEN_STATUS
    elsif us_citizen
      new_status = ::ConsumerRole::US_CITIZEN_STATUS
    elsif eligible_immigration_status
      new_status = ::ConsumerRole::ALIEN_LAWFULLY_PRESENT_STATUS
    elsif eligible_immigration_status.nil?
      new_status = ::ConsumerRole::NOT_LAWFULLY_PRESENT_STATUS
    else
      errors.add(:base, "Citizenship status can't be nil.")
    end
    consumer_role.lawful_presence_determination.assign_citizen_status(new_status) if new_status
  end

  def agent?
    agent = csr_role || assister_role || broker_role || hbx_staff_role || general_agency_staff_roles.present?
    !!agent
  end

  def contact_info(email_address, area_code, number, extension)
    if email_address.present?
      email = emails.detect{|mail| mail.kind == 'work'}
      if email
        email.update_attributes!(address: email_address)
      else
        email = Email.new(kind: 'work', address: email_address)
        emails.append(email)
        update_attributes!(emails: emails)
        save!
      end
    end
    phone = phones.detect{|p| p.kind == 'work'}
    if phone
      phone.update_attributes!(area_code: area_code, number: number, extension: extension)
    else
      phone = Phone.new(kind: 'work', area_code: area_code, number: number, extension: extension)
      phones.append(phone)
      update_attributes!(phones: phones)
      save!
    end
  end

  def generate_family_search
    ::MapReduce::FamilySearchForPerson.populate_for(self)
  end

  def set_ridp_for_paper_application(session_var)
    return unless user && session_var == 'paper'

    user.ridp_by_paper_application
  end

  def attributes_changed?
    # Check if there are meaningful changes in the person attributes or embedded documents
    meaningful_changes?(changed_attributes) || embedded_attributes_changed?
  end

  private

  # Determine if there are meaningful changes, excluding specific attributes
  #
  # @param changes [Hash] The changed attributes
  # @return [Boolean] true if there are meaningful changes, false otherwise
  def meaningful_changes?(changes)
    meaningful_changes = changes.except('updated_at', 'updated_by', 'updated_by_id')
    meaningful_changes.present?
  end

  # Check if there are changes in the embedded addresses, phones, or emails
  #
  # @return [Boolean] true if there are changes in embedded documents, false otherwise
  def embedded_attributes_changed?
    addresses.any?(&:address_changed?) || phones.any?(&:phone_changed?) || emails.any?(&:email_changed?)
  end

  def update_census_dependent_relationship(existing_relationship)
    return unless existing_relationship.valid?

    Operations::CensusMembers::Update.new.call(relationship: existing_relationship, action: 'update_relationship')
  end

  def create_inbox
    welcome_subject = "Welcome to #{site_short_name}"
    welcome_body = "#{site_short_name} is the #{aca_state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your health needs and budgets."
    mailbox = Inbox.create(recipient: self)
    mailbox.messages.create(subject: welcome_subject, body: welcome_body, from: site_short_name.to_s)
  end

  def update_full_name
    full_name
  end

  def no_changing_my_user
    return unless persisted? && user_id_changed?

    old_user, new_user = user_id_change
    return if old_user.blank?

    return unless old_user != new_user

    errors.add(:base, "you may not change the user_id of a person once it has been set and saved")
  end

  # Verify basic date rules
  def date_functional_validations
    date_of_death_is_blank_or_past
    date_of_death_follows_date_of_birth
  end

  def date_of_death_is_blank_or_past
    return unless date_of_death.present?

    errors.add(:date_of_death, "future date: #{date_of_death} is invalid date of death") if TimeKeeper.date_of_record < date_of_death
  end

  def date_of_death_follows_date_of_birth
    return unless date_of_death.present? && dob.present?

    return unless date_of_death < dob

    errors.add(:date_of_death, "date of death cannot preceed date of birth")
    errors.add(:dob, "date of birth cannot follow date of death")
  end

  def consumer_fields_validations
    return unless @is_consumer_role.to_s == "true" #&& consumer_role.is_applying_coverage.to_s == "true" #only check this for consumer flow.

    citizenship_validation
    native_american_validation
    incarceration_validation
  end

  def native_american_validation
    errors.add(:base, "American Indian / Alaskan Native status is required.") if indian_tribe_member.to_s.blank?
    if !tribal_id.present? && @us_citizen == true && @indian_tribe_member == true
      errors.add(:base, "Tribal id is required when native american / alaskan native is selected")
    elsif tribal_id.present? && !tribal_id.match("[0-9]{9}")
      errors.add(:base, "Tribal id must be 9 digits")
    end
  end

  def citizenship_validation
    if @us_citizen.to_s.blank?
      errors.add(:base, "Citizenship status is required.")
    elsif @us_citizen == false && @eligible_immigration_status.nil?
      errors.add(:base, "Eligible immigration status is required.")
    elsif @us_citizen == true && @naturalized_citizen.nil?
      errors.add(:base, "Naturalized citizen is required.")
    end
  end

  def incarceration_validation
    errors.add(:base, "Incarceration status is required.") if is_incarcerated.to_s.blank?
  end
end
