class Permission
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps

  PERMISSION_KINDS = ["hbx_staff", "hbx_read_only", "hbx_csr_supervisor", "hbx_csr_tier1", "hbx_csr_tier2", "hbx_tier3", "developer", "super_admin"].freeze

  field :name, type: String

  field :modify_family, type: Mongoid::Boolean, default: false
  field :modify_employer, type: Mongoid::Boolean, default: false
  field :revert_application, type: Mongoid::Boolean, default: false
  field :list_enrollments, type: Mongoid::Boolean, default: false
  field :send_broker_agency_message, type: Mongoid::Boolean, default: false
  field :approve_broker, type: Mongoid::Boolean, default: false
  field :approve_ga, type: Mongoid::Boolean, default: false
  field :modify_admin_tabs, type: Mongoid::Boolean, default: false
  field :view_admin_tabs, type: Mongoid::Boolean, default: false
  field :can_update_ssn, type: Mongoid::Boolean, default: false
  field :can_complete_resident_application, type: Mongoid::Boolean, default: false
  field :can_add_sep, default: false
  field :can_lock_unlock, type: Mongoid::Boolean, default: false
  field :can_view_username_and_email, type: Mongoid::Boolean, default: false
  field :can_reset_password, type: Mongoid::Boolean, default: false
  field :can_extend_open_enrollment, type: Mongoid::Boolean, default: false
  field :can_create_benefit_application, type: Mongoid::Boolean, default: false
  field :can_change_fein, type: Mongoid::Boolean, default: false
  field :can_force_publish, type: Mongoid::Boolean, default: false

  class << self
    def hbx_staff
      Permission.where(name: 'hbx_staff').first
    end
  end
end
