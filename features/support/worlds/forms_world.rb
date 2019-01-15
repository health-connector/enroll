module FormsWorld

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
    fill_in 'agency_staff_roles_attributes_0_first_name', with: "Employer"
    fill_in 'agency_staff_roles_attributes_0_last_name', with: 'One'
    fill_in 'inputDOB', with: '10/01/1990'
    fill_in 'agency_staff_roles_attributes_0_email', with: 'employerone@test.com'
    fill_in 'agency_staff_roles_attributes_0_area_code', with: '508'
    fill_in 'inputNumber', with: '2345111', match: :first
    fill_in 'agency_organization_legal_name', with: registering_employer.legal_name
    fill_in 'agency_organization_dba', with: registering_employer.dba
    fill_in 'agency_organization_fein', with: registering_employer.fein
    select 'Tax Exempt Organization', from: 'agency_organization_entity_kind'
    select '0111', from: 'agency_organization_profile_attributes_sic_code'
    fill_in 'inputAddress1', with: registering_employer.employer_profile.office_locations.first.address.address_1
    fill_in 'agency_organization_profile_attributes_office_locations_attributes_0_address_attributes_city', with: registering_employer.employer_profile.office_locations.first.address.city
    select registering_employer.employer_profile.office_locations.first.address.state, from: 'inputState'
    fill_in 'inputAreacode', with: registering_employer.employer_profile.office_locations.first.phone.area_code
    fill_in 'inputZip', with: registering_employer.employer_profile.office_locations.first.address.zip
    all('#inputNumber').last.set(registering_employer.employer_profile.office_locations.first.phone.number)
    select 'Radio', from: 'referred-by-select'
  end

  def fill_in_some_of_employer_registration_form
    fill_in 'inputDOB', with: '10/01/1990'
    fill_in 'agency_staff_roles_attributes_0_email', with: 'employerone@test.com'
    fill_in 'agency_staff_roles_attributes_0_area_code', with: '508'
    fill_in 'inputNumber', with: '2345111', match: :first
    fill_in 'agency_organization_legal_name', with: registering_employer.legal_name
    fill_in 'agency_organization_dba', with: registering_employer.dba
    fill_in 'agency_organization_fein', with: registering_employer.fein
    select 'Tax Exempt Organization', from: 'agency_organization_entity_kind'
    select '0111', from: 'agency_organization_profile_attributes_sic_code'
    fill_in 'inputAddress1', with: registering_employer.employer_profile.office_locations.first.address.address_1
    fill_in 'agency_organization_profile_attributes_office_locations_attributes_0_address_attributes_city', with: registering_employer.employer_profile.office_locations.first.address.city
    select registering_employer.employer_profile.office_locations.first.address.state, from: 'inputState'
    fill_in 'inputAreacode', with: registering_employer.employer_profile.office_locations.first.phone.area_code
    fill_in 'inputZip', with: registering_employer.employer_profile.office_locations.first.address.zip
    all('#inputNumber').last.set(registering_employer.employer_profile.office_locations.first.phone.number)
    select 'Radio', from: 'referred-by-select'
  end

  def fill_entire_benefit_package_form
    find('.interaction-choice-control-bastartdate').click
    find('.interaction-choice-control-bastartdate-1').click
    find('#fteEmployee').set(5)
    find('#pteEmployee').set(5)
  end

  def fill_in_prospective_employer_form
    # Fill form
    wait_for_ajax
    fill_in(
      'organization[legal_name]',
      with: registering_employer.legal_name
    )
    fill_in(
      'organization[dba]',
      with: "123123"
    )
    # This element is considered hidden with visible: true for some reason
    Capybara.ignore_hidden_elements = false
    select(
      '0112',
      from: 'organization[sic_code]'
    )
    Capybara.ignore_hidden_elements = true
    fill_in(
      'organization[office_locations_attributes][0][address_attributes][address_1]',
      with: "123 Main Street"
    )
    fill_in(
      'organization[office_locations_attributes][0][address_attributes][city]',
      with: "Boston"
    )
    select(
      registering_employer.employer_profile.office_locations.first.address.state,
      from: 'organization[office_locations_attributes][0][address_attributes][state]'
    )
    fill_in(
      'organization[office_locations_attributes][0][address_attributes][zip]',
      with: registering_employer.employer_profile.office_locations.first.address.zip
    )
    fill_in(
      'organization[office_locations_attributes][0][phone_attributes][area_code]',
      with: registering_employer.employer_profile.office_locations.first.phone.area_code
    )
    fill_in(
      'organization[office_locations_attributes][0][phone_attributes][number]',
      with: "1234567"
    )
    fill_in(
      'organization[office_locations_attributes][0][phone_attributes][extension]',
      with: "123"
    )
    wait_for_ajax
    select(
      'Tax Exempt Organization',
      from: 'organization[entity_kind]'
    )
    select(
      'Primary',
      from: 'organization[office_locations_attributes][0][address_attributes][kind]'
    )
    click_button 'Confirm'
  end

  def fill_in_quotes_form
    fill_in("forms_plan_design_proposal[title]", with: "Quote Name")
    date_select = find(:xpath, "//*[@id='new_forms_plan_design_proposal']/div[1]/div/div[1]/div[2]/div/div[2]/div/div[2]/p")
    date_select.click
    date_select_options = page.all(".interaction-choice-control-forms-plan-design-proposal-effective-date-1")
    # This is the right one for the March 2019 (or whatever the date will be)
    date_select_options[1].trigger('click')
  end
end

World(FormsWorld)

Given(/^all required fields have valid inputs on the Employer Registration Form$/) do
  fill_in_employer_registration_form
end

Given(/^at least one required field is blank on the Employer Registration Form$/) do
  fill_in_some_of_employer_registration_form
end

When(/^the user completely fills out the Benefit Package form$/) do
  fill_entire_benefit_package_form
end

When(/^the user enters a quote name and selects a plan year effective date$/) do
  fill_in_quotes_form
end

When(/^the user fills out and submits the Prospective Employer form$/) do
  fill_in_prospective_employer_form
end
