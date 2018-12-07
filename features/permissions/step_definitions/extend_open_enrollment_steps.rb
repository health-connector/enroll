When(/^the user clicks (.*?) for that Employer$/) do |action|
  case action
    when "Action"
      find('.dropdown.pull-right').click
  end
end

Then(/^the user will see the Extend Open Enrollment button$/) do
  expect(page).to have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

Then(/^the user will not see the Extend Open Enrollment button$/) do
  expect(page).to_not have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end
