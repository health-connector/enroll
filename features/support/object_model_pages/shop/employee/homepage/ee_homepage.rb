# frozen_string_literal: true

#families/home
class EmployeeHomepage

  def self.my_health_connector_link
    '.interaction-click-control-my-health-connector'
  end

  def self.my_broker_link
    'a[href*="/insured/families/brokers"]'
  end

  def self.messages_link
    'a[href*="/insured/families/inbox"]'
  end

  def self.manage_family_btn
    'a[href*="/insured/families/manage_family"]'
  end

  def self.shop_for_plans_btn
    'button[class*="interaction-click-control-shop-for-plans"]'
  end

  def self.shop_for_plans_qle_btn
    'a[href^="/insured/family_members"]'
  end

  def self.started_a_new_job_link
    '.interaction-click-control-started-a-new-job'
  end

  def self.married_link
    '.interaction-click-control-married'
  end

  def self.entered_into_legal_link
    '.interaction-click-control-entered-into-a-legal-domestic-partnership'
  end

  def self.had_a_baby_link
    '.interaction-click-control-had-a-baby'
  end

  def self.adopted_a_child_link
    '.interaction-click-control-adopted-a-child'
  end

  def self.qle_date
    'qle_date'
  end

  def self.effective_date_continue_btn
    'a[id="qle_submit"]'
  end

  def self.continue_qle_btn
    'input[class$="interaction-click-control-continue"]'
  end
end