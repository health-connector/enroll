module FormsWorld

  def fill_in_employer_registration_form_as_admin
    fill_in 'agency_organization_legal_name', with: registering_employer.legal_name
    fill_in 'agency_organization_dba', with: registering_employer.dba
    fill_in 'agency_organization_fein', with: registering_employer.fein
    select 'Tax Exempt Organization', from: 'agency_organization_entity_kind'
    #select "Wheat - 0111", from: "agency_organization_profile_attributes_sic_code"
    fill_in 'inputAddress1', with: registering_employer.employer_profile.office_locations.first.address.address_1
    fill_in 'agency_organization_profile_attributes_office_locations_attributes_0_address_attributes_city', with: registering_employer.employer_profile.office_locations.first.address.city
    select registering_employer.employer_profile.office_locations.first.address.state, from: 'inputState'
    fill_in 'inputZip', with: registering_employer.employer_profile.office_locations.first.address.zip
    fill_in 'inputAreacode', with: registering_employer.employer_profile.office_locations.first.phone.area_code
    fill_in 'inputNumber', with: registering_employer.employer_profile.office_locations.first.phone.number
    select 'Radio', from: 'referred-by-select'
  end
end

World(FormsWorld)

Given(/^all required fields have valid inputs on the Employer Registration Form$/) do
  if @admin
    fill_in_employer_registration_form_as_admin
  else
  end
end
