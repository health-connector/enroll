require File.join(Rails.root, "lib/mongoid_migration_task")

class RemoveEmployerStaffRoleFromPerson< MongoidMigrationTask
  def migrate
    begin
      hbx_id = ENV['person_hbx_id']
      employer_staff_role_id = ENV['employer_staff_role_id']
      person = Person.where(hbx_id:hbx_id).first
      if person.nil?
        puts "No person was found by the given hbx_id: #{hbx_id}" unless Rails.env.test?
      elsif person.employer_staff_roles.size < 1
        puts "No employer staff roles found for person with given hbx_id: #{hbx_id}" unless Rails.env.test?
      else
        employer_staff_role = person.employer_staff_roles.find(employer_staff_role_id.to_s)
        unless employer_staff_role
          puts "Could not find employer staff role with given id: #{employer_staff_role_id}" unless Rails.env.test?
          exit
        end

        employer_staff_role.close_role
        employer_staff_role.update_attributes!(is_active: false)
        puts "The target employer staff role of person with given hbx_id: #{hbx_id} has been closed" unless Rails.env.test?
      end
    rescue Exception => e
      puts "Raise error: #{e.message}" unless Rails.env.test?
    end
  end
end
