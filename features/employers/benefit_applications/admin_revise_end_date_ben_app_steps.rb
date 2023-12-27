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

When("Admin clicks on Revise End Date button") do
  find('li', :text => 'Revise End Date').click
end

Then(/^Admin will see Revise End Date Start Date for (.*) benefit application$/) do |aasm_state|
  ben_app = ::BenefitSponsors::Organizations::Organization.find_by(legal_name: /ABC Widgets/).active_benefit_sponsorship.benefit_applications.first
  expect(page.all('tr').detect { |tr| tr[:id] == ben_app.id.to_s }.present?).to eq true
  if ['terminated','termination_pending'].include?(aasm_state)
    date = ben_app.end_on - 2.months
    date_to_set = date.strftime('%m/%d/%Y')
    fill_in "date_picker_#{ben_app.id}", with: date_to_set
  end
  page.execute_script("$('#date_picker_#{ben_app.id}').blur()")
end

Then("Admin will see Revise End Date confirmation pop up modal") do
  expect(page).to have_content('Are you sure you want to change the end date?')
end

When("Admin clicks on continue button for revise_end_date benefit application") do
  click_button 'Yes, Change Date'
  wait_for_ajax
end
