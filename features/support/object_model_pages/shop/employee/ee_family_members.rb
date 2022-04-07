# frozen_string_literal: true

#insured/family_members?qle_id
class EmployeeFamilyMembers

  def self.add_member_btn
    'a[href*="/insured/family_members/new"]'
  end

  def self.continue_btn
    'a[id="btn_household_continue"]'
  end

  def self.dependent_first_name
    'dependent[first_name]'
  end

  def self.dependent_middle_name
    'dependent[middle_name]'
  end

  def self.dependent_last_name
    'dependent[last_name]'
  end

  def self.dependent_dob
    'jq_datepicker_ignore_dependent[dob]'
  end

  def self.dependent_ssn
    'dependent[ssn]'
  end

  def self.dependent_no_ssn_checkbox
    'input[id="dependent_no_ssn"]'
  end

  def self.dependent_male_radiobtn
    'label[for="radio_male"] span'
  end

  def self.dependent_female_radiobtn
    'label[for="radio_female"] span'
  end

  def self.dependent_relationship_dropdown
    'div[class*="col-xs-3"] p[class="label"]'
  end

  def self.spouse
    'div.selectric-open li[data-index="1"]'
  end

  def self.child
    'div.selectric-open li[data-index="3"]'
  end

  def self.dependent_address_line_one
    'dependent[addresses][0][address_1]'
  end

  def self.dependent_address_line_two
    'dependent[addresses][0][address_2]'
  end

  def self.dependent_city
    'dependent[addresses][0][city]'
  end

  def self.dependent_select_state_dropdown
    'div[id="address_info"] p[class="label"]'
  end

  def self.dependent_select_ma_state
    'div#address_info li[data-index="24"]'
  end

  def self.dependent_select_dc_state
    'div#address_info li[data-index="10"]'
  end

  def self.dependent_zip
    'dependent[addresses][0][zip]'
  end

  def self.cancel_btn
    'a[class*="btn-default remove-new-employee-dependent"]'
  end

  def self.confirm_member_btn
    'span[class*="btn-primary"]'
  end

  def self.pencil_edit_btn
    'i[class$="fa-pencil-alt"]'
  end
end