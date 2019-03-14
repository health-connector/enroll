module FormWorld
  def fill_in_admin_create_plan_year_form
    first_element = find("#baStartDate > option:nth-child(2)").text
    select(first_element, :from => "baStartDate")
    find('#fteCount').set(5)
  end

  def fill_in_partial_create_plan_year_form
    first_element = find("#baStartDate > option:nth-child(2)").text
    select(first_element, :from => "baStartDate")
    find('#fteCount').set(5)
    find('#open_enrollment_end_on').set('')
  end

  def generate_sic_codes
    cz_pattern = Rails.root.join("db", "seedfiles", "fixtures", "sic_codes", "sic_code_*.yaml")

    Mongoid::Migration.say_with_time("Load SIC Codes") do
      Dir.glob(cz_pattern).each do |f_name|
        loaded_class_1 = ::SicCode
        yaml_str = File.read(f_name)
        data = YAML.load(yaml_str)
        data.new_record = true
        data.save!
      end
    end
  end

  def fill_in_employer_registration_form
    phone_number2 = page.all('input').select { |input| input[:id] == "inputNumber" }[1]

    fill_in 'agency_organization_legal_name', with: registering_employer.legal_name
    fill_in 'agency_organization_dba', with: registering_employer.dba
    fill_in 'agency_organization_fein', with: registering_employer.fein
    select 'Tax Exempt Organization', from: 'agency_organization_entity_kind'
    select "0111", from: "agency_organization_profile_attributes_sic_code"
    fill_in 'inputAddress1', with: registering_employer.employer_profile.office_locations.first.address.address_1
    fill_in 'agency_organization_profile_attributes_office_locations_attributes_0_address_attributes_city', with: registering_employer.employer_profile.office_locations.first.address.city
    select registering_employer.employer_profile.office_locations.first.address.state, from: 'inputState'
    fill_in 'inputZip', with: registering_employer.employer_profile.office_locations.first.address.zip
    fill_in 'inputAreacode', with: registering_employer.employer_profile.office_locations.first.phone.area_code
    phone_number2.set registering_employer.employer_profile.office_locations.first.phone.number
    select 'Radio', from: 'referred-by-select'
  end

  def fill_in_registration_form_employer_personal_information_registration_form
    phone_number1 = page.all('input').select { |input| input[:id] == "inputNumber" }[0]
    
    fill_in 'agency_staff_roles_attributes_0_first_name', :with => 'John'
    fill_in 'agency_staff_roles_attributes_0_last_name', :with => 'Doe'
    fill_in 'inputDOB', :with =>  "08/13/1979"
    fill_in 'agency_staff_roles_attributes_0_email', :with => 'tronics@example.com'
    fill_in 'agency_staff_roles_attributes_0_area_code', :with => '202'
    phone_number1.set '5551212'
  end


end

World(FormWorld)

Given(/^all required fields have valid inputs on the Employer Registration Form$/) do
  fill_in_registration_form_employer_personal_information_registration_form
  fill_in_employer_registration_form
end

Then(/^the Create Plan Year form will auto-populate the available dates fields$/) do
  expect(find('#end_on').value.blank?).to eq false
  expect(find('#open_enrollment_end_on').value.blank?).to eq false
  expect(find('#open_enrollment_start_on').value.blank?).to eq false
end

Then(/^the Create Plan Year form submit button will be disabled$/) do
  expect(page.find("#adminCreatePyButton")[:class].include?("disabled")).to eq true
end

Then(/^the Create Plan Year form submit button will not be disabled$/) do
  expect(page.find("#adminCreatePyButton")[:class].include?("disabled")).to eq false
end

Then(/^the Create Plan Year option row will no longer be visible$/) do
  expect(page).to_not have_css('label', text: 'Effective Start Date')
  expect(page).to_not have_css('label', text: 'Effective End Date')
  expect(page).to_not have_css('label', text: 'Full Time Employees')
  expect(page).to_not have_css('label', text: 'Open Enrollment Start Date')
  expect(page).to_not have_css('label', text: 'Open Enrollment End Date')
end

Then(/^the Effective End Date for the Create Plan Year form will be blank$/) do
  expect(find('#end_on').value.blank?).to eq true
end

Then(/^the Open Enrollment Start Date for the Create Plan Year form will be disabled$/) do
  expect(page.find("#open_enrollment_start_on")[:class].include?("blocking")).to eq true
end

Then(/^the Open Enrollment End Date for the Create Plan Year form will be disabled$/) do
  expect(page.find("#open_enrollment_end_on")[:class].include?("blocking")).to eq true
end

Then(/^the Open Enrollment Start Date for the Create Plan Year form will be enabled$/) do
  expect(page.find("#open_enrollment_start_on")[:class].include?("blocking")).to eq false
end

Then(/^the Open Enrollment End Date for the Create Plan Year form will be enabled$/) do
  expect(page.find("#open_enrollment_end_on")[:class].include?("blocking")).to eq false
end

Then(/^the Effective End Date for the Create Plan Year form will be filled in$/) do
  expect(find('#end_on').value.blank?).to eq false
end

And(/^the user is on the Employer Registration page$/) do
  #visit '/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=benefit_sponsor'
  visit '/'
  find('.btn.btn-default.interaction-click-control-employer-portal').click
end

And(/^the user is registering a new Employer$/) do
  registering_employer
end

When(/^the user clicks the 'Confirm' button on the Employer Registration Form$/) do
  find('form#new_agency input[type="submit"]').click
  # expect(page).to have_css('legend', text: 'Balscssc')
  find('.alert', text: "Welcome to Health Connector. Your account has been created.")
end
