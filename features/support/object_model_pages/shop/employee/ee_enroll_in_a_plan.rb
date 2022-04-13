# frozen_string_literal: true

#insured/product_shoppings/continuous_show
class EmployeeEnrollInAPlan

  def self.find_your_doctor_btn
    'button[class$="interaction-click-control-find-your-doctor"]'
  end

  def self.plan_name_btn
    'a[class$="interaction-click-control-plan-name"]'
  end

  def self.premium_amount_btn
    'a[class$="interaction-click-control-premium-amount"]'
  end

  def self.deductible_btn
    'a[class$="interaction-click-control-deductible"]'
  end

  def self.carrier_btn
    'a[class$="interaction-click-control-carrier"]'
  end

  def self.select_plan_btn
    'a[class$="interaction-click-control-select-plan"]'
  end

  def self.see_details_btn
    'a[class$="interaction-click-control-see-details"]'
  end

  def self.back_to_results_btn
    'a[class$="all-plans"]'
  end

  def self.dental_header_text
    'Enroll in a Dental Plan'
  end

  def self.health_header_text
    'Enroll in a Health Plan'
  end

  def self.plan_count
    '[data-cuke="plan-count"]'
  end

  def self.coverage_for
    '[data-cuke="coevrage-for"]'
  end

  def self.previous
    'a[class="interaction-click-control-previous"]'
  end

  def self.save_and_exit
    'a[class="interaction-click-control-save---exit"]'
  end

  def self.find_your_doctor_link
    '.interaction-click-control-find-your-doctor'
  end
end