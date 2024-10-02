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

When(/^the user will see Marketplace Plan Year Index table$/) do
  expect(page).to have_text('Type')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Marking(s)')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

When(/^the user will see Marketplace Carriers table$/) do
  expect(page).to have_text('Carrier')
  expect(page).to have_text('Plans')
  expect(page).to have_text('PVP Marking(s)')
  expect(page).to have_text('Enrollments')
  expect(page).to have_text('Products')
  expect(page).to have_css('.table-responsive .table thead')
end

Then('the table should have {string} in the {string} column') do |value, column_name|
  value = Date.today.year if column_name == 'Year' && value == "current_year"
  table = find('.table-responsive table.table-wrapper')
  column_index = table.find('thead tr th', text: column_name, exact_text: true).path.split('/')[-1][/\d+/].to_i

  expect(table).to have_xpath(".//tbody/tr/td[#{column_index}]", text: value)
end

And(/^the user visit the Marketplace Plan Year Index page$/) do
  find('a[aria-label="SHOP"]').click
end

And(/^the user visit the Marketplace Carriers page$/) do
  year = Time.now.year
  find("a[aria-label='#{year}']").click
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
  expect(page).to have_text('Metal level')
  expect(page).to have_css('.table-responsive .table thead')
end

When('check the {string} filter {string}') do |value, column_name|
  column_value = value == 'PVP rating areas' ? column_name : column_name.downcase
  find("input[name='#{value.parameterize(separator: '_')}[]'][value='#{column_value}']").check
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

And(/^the user visit the Detail Plan page$/) do
  year = Time.now.year
  carrier = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.first
  product = BenefitMarkets::Products::Product.where(
    :"application_period.min".lte => Date.new(year, 12, 31),
    :"application_period.max".gte => Date.new(year, 1, 1),
    :issuer_profile_id.in => carrier.profiles.map(&:_id),
    :kind => :health
  ).first
  visit plan_details_exchanges_hbx_profiles_path(year: year, market: 'shop', id: carrier.id, product_id: product.id)
end

And(/^the user should see Plan title$/) do
  expect(page).to have_css('h4', text: 'BlueChoice bronze 2,000')
end

And(/^the user should see Plan benefit type$/) do
  expect(page).to have_css(".benefit", text: 'Health')
end

And(/^the user should see Plan metal tier$/) do
  expect(page).to have_css(".metal-tier", text: 'Gold')
end

And(/^the user should see Plan PVP areas$/) do
  expect(page).to have_css(".pvp-areas", text: '1')
end

And(/^the user should see HIOS id$/) do
  expect(page).to have_css(".plan_id", text: '41842DC0400010-01')
end

And(/^the user should see Availability table$/) do
  expect(page).to have_css('table.table.availability-table')

  expect(page).to have_css('thead tr th', text: "Rating Area")
  expect(page).to have_css('thead tr th', text: "Active")
  expect(page).to have_css('thead tr th', text: "PVP Active")
end

And(/^the user should see Estimated Cost table$/) do
  within '.details' do
    expect(page).to have_css('table.table')

    within 'table.table thead tr' do
      expect(page).to have_css('th', text: "Services You May Need")
      expect(page).to have_css('th', text: "Your Cost At Participating Provider Co-Pay")
      expect(page).to have_css('th', text: "(In Network) Coinsurance")
    end
  end
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