# frozen_string_literal: true

#insured/members_selections/new?change_plan
class EmployeeChooseCoverage
  
  def self.enroll_health
    '[data-cuke="health-enroll-radio"]'
  end

  def self.waive_health
    '[data-cuke="health-waive-radio"]'
  end

  def self.enroll_dental
    '[data-cuke="dental-enroll-radio"]'
  end

  def self.waive_dental
    '[data-cuke="dental-waive-radio"]'
  end

  def self.shop_for_new_plan_btn
    'input[class$="interaction-click-control-shop-for-new-plan"]'
  end

  def self.back_to_my_account_btn
    'a[class$="interaction-click-control-back-to-my-account"]'
  end
end