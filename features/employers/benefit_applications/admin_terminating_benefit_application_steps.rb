# frozen_string_literal: true

Then(/^the user will select benefit application to (.*)$/) do |aasm_state|
  if aasm_state == "terminate"
    find(:xpath, '//input[@status="active"]').click
  else
    find(:xpath, '//input[@name="plan_year_radio"]').click
  end
end

When(/^the user clicks Actions for that benefit application$/) do
  find_all('.py-btn-grp', text: 'Actions').detect { |element| element[:class].exclude?('disabled') }.click
end

When(/^the user clicks Actions for current benefit application$/) do
  find_all('.py-btn-grp', text: 'Actions').detect { |element| element[:class].exclude?('disabled') }.click
  sleep 2
  buttons = page.all('button')
  actions_button = buttons.detect { |button| button[:class].include?('py-btn-grp') && button.text == 'Actions' }
  actions_button.click
end

Then(/^the user will see Terminate button$/) do
  find('li', :text => 'Terminate').click
end

When(/^the user enters (mid_month|any_day|last_day) and other details for (voluntary|non-payment) termination$/) do |termination_date, termination_type|
  if termination_type == 'voluntary'
    find(:xpath, '//input[@id="term_actions_voluntary"]').click
  else
    find(:xpath, '//input[@id="term_actions_nonpayment"]').click
  end
  find('.term_action_radios select').find(:xpath, 'option[2]').select_option


  case termination_date
  when 'mid_month'
    fill_in "Select Term Date", with: TimeKeeper.date_of_record.end_of_month.prev_day.strftime('%m/%d/%Y').to_s
  when 'any_day'
    fill_in "Select Term Date", with: TimeKeeper.date_of_record.end_of_month.strftime('%m/%d/%Y').to_s
  when 'last_day'
    fill_in "Select Term Date", with: @new_application.end_on.to_s
  end
  find('h1', :text => 'Employers', wait: 10).click
end

When(/^user clicks submit button$/) do
  find('.plan-year-submit', text: 'Submit', wait: 5).click
end

And(/^employer clicks OK in warning modal$/) do
  find(:button, "OK", wait: 2).click
end

And(/^employer clicks Add Plan Year link$/) do
  find('.interaction-click-control-add-plan-year', text: 'Add Plan Year').click
end

Then(/^user should see termination successful message$/) do
  expect(page).to have_content('Application terminated successfully')
end

Then(/^employer should see benefit application in termination pending state$/) do
  expect(page).to have_content("Termination Pending")
end

And(/^employer should see Add Plan Year link$/) do
  sleep(2)
  links = page.all('a')
  add_plan_year_link = links.detect { |link| link.text == 'Add Plan Year' }
  expect(add_plan_year_link.nil?).to eq(false)
end
