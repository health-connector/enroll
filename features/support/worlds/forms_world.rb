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
end

World(FormsWorld)

Given(/^all required fields have valid inputs on the Employer Registration Form$/) do
  fill_in_employer_registration_form
end

Given(/^at least one required field is blank on the Employer Registration Form$/) do
  fill_in_some_of_employer_registration_form
end
