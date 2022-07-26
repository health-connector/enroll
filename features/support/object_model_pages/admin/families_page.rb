# frozen_string_literal: true

#exchanges/hbx_profiles

class FamiliesPage

  def self.all_btn
    'div[id="Tab:all"]'
  end

  def self.employer_sponsored_coverage_btn
    'div[id="Tab:by_enrollment_shop_market"]'
  end

  def self.anon_enrolled_btn
    'div[id="Tab:non_enrolled"]'
  end

  def self.csv_btn
    'a[class*=" buttons-csv"]'
  end

  def self.excel_btn
    'a[class*="buttons-excel"]'
  end

  def self.x_btn
    'div[class^="datatable_clear"]'
  end

  def self.actions_dropdown
    'button[id^="dropdown_for_family_actions"]'
  end

  def self.add_sep_btn
    'a[href^="/exchanges/hbx_profiles/add_sep_form"]'
  end

  def self.view_sep_history_btn
    'a[href^="/exchanges/hbx_profiles/show_sep_history"]'
  end

  def self.cancel_enrollment_btn
    'a[href^="/exchanges/hbx_profiles/cancel_enrollment"]'
  end

  def self.terminate_enrollment_btn
    'a[href^="/exchanges/hbx_profiles/terminate_enrollment"]'
  end

  def self.change_enr_end_date_btn
    'a[href^="/exchanges/hbx_profiles/view_enrollment_to_update_end_date"]'
  end

  def self.reinstate_btn
    'a[href^="/exchanges/hbx_profiles/view_terminated_hbx_enrollments"]'
  end

  def self.edit_dob_snn_btn
    'a[href^="/hbx_profiles/edit_dob_ssn"]'
  end

  def self.send_secure_msg_btn
    'a[href^="/insured/inboxes/new"]'
  end

  def self.view_username_email_btn
    'a[href^="/exchanges/hbx_profiles/get_user_info"]'
  end

  def self.collapse_form_btn
    'a[href^="/exchanges/hbx_profiles/hide_form"]'
  end
end