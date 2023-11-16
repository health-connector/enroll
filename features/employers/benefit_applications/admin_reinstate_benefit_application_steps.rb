# frozen_string_literal: true

Given(/^the Reinstate feature configuration is enabled$/) do
  enable_feature :benefit_application_reinstate
end

Given(/^the Reinstate feature configuration is disabled$/) do
  disable_feature :benefit_application_reinstate
end

And(/^initial employer ABC Widgets has updated (.*) effective period for reinstate$/) do |aasm_state|
  if aasm_state == 'terminated'
    employer_profile.benefit_applications.first.workflow_state_transitions << WorkflowStateTransition.new(from_state: 'active', to_state: 'terminated', event: 'terminate!')
    term_ba = employer_profile.benefit_applications.first
    start_on = term_ba.benefit_sponsor_catalog.effective_period.min
    end_on = term_ba.benefit_sponsor_catalog.effective_period.max
    effective_period = start_on..end_on
    term_ba.benefit_sponsor_catalog.update_attributes!(effective_period: effective_period)
    employer_profile.benefit_applications.first.update_attributes!(effective_period: effective_period)
  end
end

Then(/the user will see a (.*) message/) do |message|
  expect(page).to have_content(message)
end

Then(/^the user will (.*) Reinstate button$/) do |action|
  action == 'see' ? (page.has_css?('Reinstate') == true) : (page.has_css?('Reinstate') == false)
end
