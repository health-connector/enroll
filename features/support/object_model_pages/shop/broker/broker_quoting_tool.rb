# frozen_string_literal: true

#families/home
class BrokerQuotingTool

  def self.plan_type_filters
    '[data-cuke="bqt-plan-type-filter"]'
  end

  def self.reference_plan
    'input[name="reference_plan"]'
  end

  def self.employee_cost_details_button
    '#estimatedEmployerCostsPage'
  end

end