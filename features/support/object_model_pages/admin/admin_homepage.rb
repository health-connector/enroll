# frozen_string_literal: true

#exchanges/hbx_profiles

class AdminHomepage

  def self.admin_icon
    'a[class="portal interaction-click-control-i\'\m-an-admin"]'
  end

  def self.families_tab
    'a[href="/exchanges/hbx_profiles/family_index_dt"]'
  end 

  def self.employers_tab
    'a[href="/exchanges/hbx_profiles/employer_datatable"]'
  end

  def self.user_accounts_tab
    'a[href="/exchanges/hbx_profiles/user_account_index"]'
  end

  def self.issuers_tab
    'a[href="/exchanges/hbx_profiles/issuer_index"]'
  end

  def self.products_tab
    'a[href="/exchanges/hbx_profiles/product_index"]'
  end
  
  def self.brokers_dropdown
    'a[class$="interaction-click-control-brokers"]'
  end

  def self.broker_applications
    'a[href="/exchanges/broker_applicants"]'
  end

  def self.broker_agencies
    'a[href="/exchanges/hbx_profiles/broker_agency_index"]'
  end

  def self.admin_dropdown
    'a[class$="interaction-click-control-admin"]'
  end
   
  def self.calendar
    'a[href="/exchanges/scheduled_events"]'
  end

  def self.config
    'a[href="/exchanges/hbx_profiles/configuration"]'
  end

  def self.staff
    'a[href="/exchanges/hbx_profiles/staff_index"]'
  end

  def self.orphan_accounts
    'a[href="/users/orphans"]'
  end

  def self.inbox_tab
    'a[href="/exchanges/hbx_profiles/1/inbox"]'
  end

  def self.notices_tab
    'a[href="/notifier/notice_kinds"]'
  end

  def self.home_icon
    'i[class*="fa-home"]'
  end

  def self.logout_btn
    'a[href="/users/sign_out"]'
  end
end