# RAILS_ENV=production rails r script/update_employee_details_70267.rb

begin
  person = Person.where(hbx_id: '140513').first
  person.update_attributes(gender: 'male')
  census_employee = CensusEmployee.where(last_name: person.last_name.upcase, id: '5dd17a42aca7d42cca07c7ad').first
  census_employee.update_attributes(aasm_state: 'eligible')
  census_employee.update_attributes!(ssn: person.ssn)
  census_employee.update_attributes(aasm_state: 'employee_role_linked')
  employer_profile = census_employee.employer_profile
  employee_role = person.employee_roles.build(employer_profile: employer_profile, hired_on: census_employee.hired_on, census_employee_id: census_employee.id)
  employee_role.save!
  census_employee.update_attributes(employee_role_id: employee_role.id)

  puts 'Updated employee details'

rescue StandardError => e
  puts 'Error while updating, contact Developer.'
  puts e.backtrace.inspect
end