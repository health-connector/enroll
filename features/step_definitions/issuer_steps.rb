# frozen_string_literal: true

When(/^the user will see Marketplaces table$/) do
  expect(page).to have_text('Type')
  expect(page).to have_text('# Plans')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

Then(/^the user will see correct content in table$/) do
  expect(find('.table-responsive .table tbody')).to have_text('SHOP')
  expect(find('.table-responsive .table tbody')).to have_text('8')
  expect(find('.table-responsive .table tbody')).to have_text('0')
  expect(find('.table-responsive .table tbody')).to have_text('Health')
end

Given(/^Admin_issuers_tab_display is on$/) do
  EnrollRegistry[:admin_issuers_tab_display].feature.stub(:is_enabled).and_return(true)
end
