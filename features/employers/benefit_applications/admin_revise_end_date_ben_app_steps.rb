# frozen_string_literal: true

Given(/^the Revise End Date feature configuration is enabled$/) do
  enable_feature :benefit_application_revise_end_date
end

Given(/^the Revise End Date feature configuration is disabled$/) do
  disable_feature :benefit_application_revise_end_date
end

Then(/^the user will (.*) Revise End Date button$/) do |action|
  action == 'see' ? (page.has_css?('Revise End Date') == true) : (page.has_css?('Revise End Date') == false)
end
