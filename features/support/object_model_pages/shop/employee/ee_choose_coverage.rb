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

  def self.confirm_your_selections
    'input[class$="interaction-click-control-confirm-your-selections"]'
  end

  def self.back_to_my_account_btn
    'a[class$="interaction-click-control-back-to-my-account"]'
  end

  def self.member_health_error
    '[data-cuke="member_health_error"]'
  end

  def self.member_dental_error
    '[data-cuke="member_dental_error"]'
  end

  def self.waiver_drop_down_for_primary
    '[id$="waiver_reasons_for_primary"]'
  end

  def self.waiver_reason_for_primary_health
    'div.selectric-open li[data-index="6"]'
  end
end
