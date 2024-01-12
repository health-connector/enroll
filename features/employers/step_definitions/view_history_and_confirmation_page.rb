# frozen_string_literal: true

Then(/^the user will see application history button$/) do
  expect(page).to have_link('View History')
end

Then(/^Admin will see Confirmation page/) do
  expect(page).to have_content('Confirmation Page')
end

Then(/^Admin will see pagination for employees/) do
  expect(page).to have_css('#pagination-buttons')
end

Then(/^Admin will see application history page/) do
  expect(page).to have_content('Application History')
end

When(/Admin clicks on application history button/) do
  find('a', :text => 'View History').click
end

Then(/admin will see option to click return to employer index view/) do
  expect(page).to have_link('Return to Employers Index View')
end

When(/admin clicks on return to employer index view link/) do
  find('a', :text => 'Return to Employers Index View').click
end

Then(/admin will go to employer index page/) do
  expect(page).to have_content('Employers')
end
