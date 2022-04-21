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

  def self.filtered_select_plan_btn
    '[data-cuke="cps-select-plan"]'
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

  def self.filtered_plan
    '[data-cuke="filtered-plan"]'
  end

  def self.plan_type_filter
    '[data-cuke="plan-type-filter"]'
  end

  def self.plan_metal_level_filter
    '[data-cuke="plan-metal-level-filter"]'
  end

  def self.plan_network_filter
    '[data-cuke="plan-network-filter"]'
  end

  def self.plan_network_filter_option
    '[data-cuke="plan-network-filter"]'
  end

  def self.plan_carrier_filter
    '[data-cuke="plan-carrier-filter"]'
  end

  def self.plan_carrier_filter_option
    '[data-cuke="plan-carrier-filter"] li'
  end

  def self.plan_hsa_filter
    '[data-cuke="plan-hsa-filter"]'
  end

  def self.plan_hsa_filter_option
    '[data-cuke="plan-hsa-filter"] li'
  end

  def self.plan_premium_filter
    '[data-cuke="plan-premium-filter"]'
  end

  def self.plan_premium_filter_from
    'plan-premium-from'
  end

  def self.plan_deductible_filter
    '[data-cuke="plan-deductible-filter"]'
  end

  def self.plan_deductible_filter_from
    'plan-deductible-from'
  end

  def self.apply_filters_btn
    '[data-cuke="apply-plan-filters-btn"]'
  end

  def self.reset_filters_btn
    '[data-cuke="reset-plan-filters-btn"]'
  end

  def self.dual_enrollment_text
    '[data-cuke="dual-enrollment-text"]'
  end

  def self.ee_choose_coverage
    '[class$="interaction-choice-control-value-eligible-continue-no"]'
  end

  def self.continue_coverage_button
    '.interaction-click-control-continue'
  end

  def self.dental_enrollment_confirmation
    'Your dental'
  end

  def self.available_coverage
    '[data-cuke="available-coverage"]'
  end

  def self.shop_for_text
    '[data-cuke="shop-for"]'
  end
end
