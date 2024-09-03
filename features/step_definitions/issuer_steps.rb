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
  expect(find('.table-responsive .table tbody')).to have_text('17')
  expect(find('.table-responsive .table tbody')).to have_text('0')
  expect(find('.table-responsive .table tbody')).to have_text('Health, Dental')
end

And(/^the user visit the Marketplace Plan Year Index page$/) do
  find('a[aria-label="SHOP"]').click
end

And(/^the user visit the Marketplace Carriers page$/) do
  year = Time.now.year
  find("a[aria-label='#{year}']").click
end

When(/^the user will see Marketplace Plan Year Index table$/) do
  expect(page).to have_text('Type')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Plans')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

When(/^the user will see Marketplace Carriers table$/) do
  expect(page).to have_text('Carrier')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Plans')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

Then('the table should have {string} in the {string} column') do |value, column_name|
  table = find('.table-responsive table.table-wrapper')
  column_index = table.find('thead tr th', text: column_name, exact_text: true).path.split('/')[-1][/\d+/].to_i

  expect(table).to have_xpath(".//tbody/tr/td[#{column_index}]", text: value)
end

And(/^the user visit the Marketplace Plan Year Index page$/) do
  find('a[aria-label="SHOP"]').click
end

And(/^the user visit the Marketplace Carrier page$/) do
  year = Time.now.year
  find("a[aria-label='#{year}']").click
end


When(/^the user will see Marketplace Plan Year Index table$/) do
  expect(page).to have_text('Type')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Plans')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

When(/^the user will see Marketplace Carrier table$/) do
  sleep 50
  expect(page).to have_text('Carrier')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Plans')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end


Then('the table should have {string} in the {string} column') do |value, column_name|
  table = find('.table-responsive table.table-wrapper')
  column_index = table.find('thead tr th', text: column_name, exact_text: true).path.split('/')[-1][/\d+/].to_i

  expect(table).to have_xpath(".//tbody/tr/td[#{column_index}]", text: value)
end


Given(/^Admin_issuers_tab_display is on$/) do
  EnrollRegistry[:admin_issuers_tab_display].feature.stub(:is_enabled).and_return(true)
end

And(/^the user visit the Marketplace Carrier page$/) do
  find("a[aria-label='Health Agency Authority']").click
end

When(/^the user will see Marketplace Carrier table$/) do
  expect(page).to have_text('Plan name')
  expect(page).to have_text('Plan type')
  expect(page).to have_text('PVP rating areas')
  expect(page).to have_text('HIOS/Plan ID')
  expect(page).to have_text('Network')
  expect(page).to have_text('Metal level')
  expect(page).to have_css('.table-responsive .table thead')
end

When('check the {string} filter {string}') do |value, column_name|
  find("input[name='#{value.parameterize(separator: '_')}[]'][value='#{column_name.downcase}']").check
end

When('click on {string}') do |button_text|
  click_button(button_text)
end

Then('should see plans with the following:') do |table|
  expected_results = table.rows_hash
  check_filtered_results(expected_results)
end

And('search for {string}') do |search_prompt|
  fill_in 'search', with: search_prompt
end

def check_filtered_results(expected_results)
  within('table tbody') do
    rows = all('tr')

    rows.each do |row|
      expected_results.each do |attribute, value|
        css_attribute = attribute.parameterize(separator: '-')
        expect(row[:"data-#{css_attribute}"].to_s).to include(value)
      end
    end
  end
end
