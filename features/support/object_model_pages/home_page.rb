# frozen_string_literal: true

#hbxshop.org
class HomePage

  def self.employee_portal_btn
    'a[href="/insured/employee/privacy"]'
  end

  def self.returning_user_btn
    'a[href="/families/home"]'
  end

  def self.employer_portal_btn
    'a[href="/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor"]'
  end

  def self.broker_agency_portal_btn
    'a[href="/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=broker_agency"]'
  end

  def self.hbx_portal_btn
    'a[class$="interaction-click-control-hbx-portal"]'
  end

  def self.broker_registration_btn
    'a[href="/benefit_sponsors/profiles/registrations/new?profile_type=broker_agency"]'
  end

  def self.logout_btn
    'a[href="/users/sign_out"]'
  end
end