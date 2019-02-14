require 'csv'

field_names = %w(
      Subscriber_FN
      Subscriber_LN
      HBX_ID)

@count = 0

file_name = "#{Rails.root}/employee_roles_without_employer_profile_id.csv"
CSV.open(file_name, 'w', force_quotes: true) do |csv|
  csv << field_names
  Person.all_employee_roles.inject([]) do |arr, person|
    begin
      if person.employee_roles.any?{ |ee_role| ee_role.benefit_sponsors_employer_profile_id.nil? }
        csv << [
          person.first_name,
          person.last_name,
          person.hbx_id
        ]
        @count += 1
      end
    rescue => e
      puts "Unable to process person with hbx_id: #{person.hbx_id}, error: #{e.message}" unless Rails.env.test?
    end
  end
end
puts "Total number of people who has employee roles without employer profile id: #{@count}" unless Rails.env.test?
