# frozen_string_literal: true

Then(/the Employee will see a Metal Level Filter/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_metal_level_filter).present?).to eq true
end

Then(/the Employee will have the ability to filter plans by metal level/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  find_all(EmployeeEnrollInAPlan.plan_metal_level_filter).first.click
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Then(/the Employee will see a Plan Type Filter/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_type_filter).present?).to eq true
end

Then(/the Employee will have the ability to filter plans by plan type/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  find_all(EmployeeEnrollInAPlan.plan_type_filter).first.click
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Given(/Nationwide markets are enabled/) do
  Settings.aca.stub(:nationwide_markets).and_return(true)
end

Then(/the Employee will see a Network Filter/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_network_filter).present?).to eq true
end

Then(/the Employee will have the ability to filter plans by network/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  find_all(EmployeeEnrollInAPlan.plan_network_filter).first.click
  find_all(EmployeeEnrollInAPlan.plan_network_filter_option).last.click
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Then(/the Employee will see a Carrier dropdown/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_carrier_filter).present?).to eq true
end

Then(/the Employee will have the ability to view plans by carrier/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  find_all(EmployeeEnrollInAPlan.plan_carrier_filter).first.click
  find_all(EmployeeEnrollInAPlan.plan_carrier_filter_option).last.click
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Then(/the Employee will see a HSA Eligible dropdown/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_hsa_filter).present?).to eq true
end

Then(/the Employee will have the ability to view plans by HSA eligibility/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  find_all(EmployeeEnrollInAPlan.plan_hsa_filter).first.click
  find_all(EmployeeEnrollInAPlan.plan_hsa_filter_option).last.click
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Then(/the Employee will see premium amount fields/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_premium_filter).present?).to eq true
end

Then(/the Employee will have the ability to enter a premium amount number range/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  fill_in EmployeeEnrollInAPlan.plan_premium_filter_from, with: 1
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 0
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end

Then(/the Employee will see deductible amount fields/) do
  expect(find_all(EmployeeEnrollInAPlan.plan_deductible_filter).present?).to eq true
end

Then(/the Employee will have the ability to enter a deductible amount number range/) do
  expect(find_all(EmployeeEnrollInAPlan.select_plan_btn).count).to be > 1
  fill_in EmployeeEnrollInAPlan.plan_deductible_filter_from, with: 1
  find(EmployeeEnrollInAPlan.apply_filters_btn).click
  expect(find_all(EmployeeEnrollInAPlan.filtered_plan).count).to eq 1
  find(EmployeeEnrollInAPlan.reset_filters_btn).click
end
