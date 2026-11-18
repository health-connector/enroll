# frozen_string_literal: true

Given(/^zip code (\d{5}) is in (.*) county$/) do |zip, county|
  FactoryBot.create(:benefit_markets_locations_county_zip, zip: zip, county_name: county, state: 'MA')
end

And(/^the employer changes the primary office zip code to (\d{5}) in (.*) county and clicks on save$/) do |zip, county|
  county_select = 'agency_organization_profile_attributes_office_locations_attributes_0_address_attributes_county'
  zip_field = find_field('agency[organization][profile_attributes][office_locations_attributes][0][address_attributes][zip]')
  zip_field.set(zip)
  # the county options reload from the zip once the field loses focus
  zip_field.send_keys(:tab)
  expect(page).to have_select(county_select, options: [county], wait: 10)
  select county, from: county_select
  find('.interaction-click-control-save').click
end

Then(/^the broker sees zip code (\d{5}) and county (.*) on the quote$/) do |zip, county|
  expect(page).to have_field('forms_plan_design_proposal_zip_code', with: zip, disabled: true)
  expect(page).to have_field('forms_plan_design_proposal_county', with: county, disabled: true)
end
