# frozen_string_literal: true

Given(/^the Reinstate feature configuration is enabled$/) do
  enable_feature :benefit_application_reinstate
end

Given(/^the Reinstate feature configuration is disabled$/) do
  disable_feature :benefit_application_reinstate
end

And(/^initial employer ABC Widgets has updated (.*) effective period for reinstate$/) do |aasm_state|
  if aasm_state == 'retroactive_canceled'
    cancel_ba = employer_profile.benefit_applications.first
    cancel_ba.workflow_state_transitions << WorkflowStateTransition.new(from_state: 'active', to_state: :retroactive_canceled, event: 'cancel!')
    start_on = cancel_ba.benefit_sponsor_catalog.effective_period.min.prev_year
    end_on = cancel_ba.benefit_sponsor_catalog.effective_period.max.prev_year
    effective_period = start_on..end_on
    cancel_ba.benefit_sponsor_catalog.update_attributes!(effective_period: effective_period)
    cancel_ba.benefit_application_items.create!(effective_period: effective_period, sequence_id: 0, state: :retroactive_canceled)
    cancel_ba.update_attributes!(aasm_state: :retroactive_canceled)
  end
end

And(/^initial employer ABC Widgets application (.*)$/) do |aasm_state|
  application = employer_profile.benefit_applications.first
  case aasm_state
  when 'termination_pending'
    updated_dates = application.effective_period.min.to_date..TimeKeeper.date_of_record.last_month.end_of_month
    application.benefit_application_items.first.update_attributes!(effective_period: updated_dates)
    application.schedule_enrollment_termination!
  when 'terminated'
    updated_dates = application.effective_period.min.to_date..TimeKeeper.date_of_record.prev_month.end_of_month
    application.benefit_application_items.first.update_attributes!(effective_period: updated_dates)
    application.terminate_enrollment!
  when 'retroactive_canceled'
    start_on = application.benefit_sponsor_catalog.effective_period.min.prev_year
    end_on = application.benefit_sponsor_catalog.effective_period.max.prev_year
    effective_period = start_on..end_on
    application.benefit_sponsor_catalog.update_attributes!(effective_period: effective_period)
    application.benefit_application_items.first.update_attributes!(effective_period: effective_period)
    application.cancel!
  end
end

Then(/^the user will (.*) Reinstate button$/) do |action|
  action == 'see' ? (page.has_css?('Reinstate') == true) : (page.has_css?('Reinstate') == false)
end

When("Admin clicks on Reinstate button") do
  find('li', :text => 'Reinstate').click
end

Then("Admin will see transmit to carrier checkbox") do
  expect(page).to have_content('Transmit to Carrier')
end

Then(/^Admin will see Reinstate Start Date for (.*) benefit application$/) do |aasm_state|
  ben_app = ::BenefitSponsors::Organizations::Organization.find_by(legal_name: /ABC Widgets/).active_benefit_sponsorship.benefit_applications.first
  expect(page.all('tr').detect { |tr| tr[:id] == ben_app.id.to_s }.present?).to eq true
  if ['terminated','termination_pending'].include?(aasm_state)
    element = find('input.uidatepicker.form-control.date.py-end-date')
    reinstate_start_date = element['reinstate_start_date']
    expect(reinstate_start_date.present?).to eq true
    expect(reinstate_start_date).to eq ben_app.end_on.to_date.next_day.to_s
  else
    expect(page).to have_content(ben_app.start_on.to_date.to_s)
  end
end

When("Admin clicks on Submit button") do
  find('.plan-year-submit').click
end

Then("Admin will see Reinstate confirmation pop up modal") do
  expect(page).to have_content('Are you sure you want to reinstate this plan year?')
end

When("Admin clicks on continue button for reinstating benefit_application") do
  click_button 'Yes, Reinstate Plan Year'
  sleep 1
end
