# frozen_string_literal: true

Given(/^(.*) exists with an SSN as a spouse on another employee's family$/) do |named_person|
  person = people[named_person]
  primary = FactoryBot.create(:person, :with_family, first_name: 'Jane', last_name: person[:last_name], dob: '1981-03-03'.to_date)
  @ssn_verified_person = FactoryBot.create(
    :person,
    first_name: person[:first_name],
    last_name: person[:last_name],
    dob: person[:dob_date],
    ssn: person[:ssn],
    gender: 'male'
  )
  primary.ensure_relationship_with(@ssn_verified_person, 'spouse')
  primary.save!
  primary.primary_family.add_family_member(@ssn_verified_person)
  primary.primary_family.save!
end

Given(/^an unrelated person named (.*) with the same DOB and no SSN exists$/) do |named_person|
  person = people[named_person]
  @name_dob_collision_person = FactoryBot.create(
    :person,
    first_name: person[:first_name],
    last_name: person[:last_name],
    dob: person[:dob_date]
  )
  expect(@name_dob_collision_person.ssn).to be_blank
end

Then(/^Employee should not see the enroll as another employee error$/) do
  expect(page).not_to have_content('You can not enroll as another employee')
end

Then(/^the employee role for (.*) should belong to the SSN-verified person$/) do |_named_person|
  @ssn_verified_person.reload
  expect(@ssn_verified_person.user).to be_present
  expect(@ssn_verified_person.active_employee_roles).not_to be_empty
end

Then(/^the unrelated (.*) record without an SSN should be unchanged$/) do |_named_person|
  @name_dob_collision_person.reload
  expect(@name_dob_collision_person.ssn).to be_blank
  expect(@name_dob_collision_person.user).to be_nil
  expect(@name_dob_collision_person.employee_roles).to be_empty
end
