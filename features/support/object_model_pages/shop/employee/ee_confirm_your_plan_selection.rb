# frozen_string_literal: true

#insured/plan_shoppings/thankyou
class EmployeeConfirmYourPlanSelection

  def self.confirm_btn
    'a[id="btn-continue"]'
  end

  def self.previous_link
    'a[class$="interaction-click-control-previous"]'
  end

  def self.save_and_exit_link
    'a[class="interaction-click-control-save---exit"]'
  end

  def self.waive_coverage_btn
    'a[class^="btn-waive"]'
  end
end