require File.join(Rails.root, "lib/mongoid_migration_task")

class ActivateBenefitGroupAssignment < MongoidMigrationTask
  def migrate
    begin
      bga_id = ENV['bga_id']
      census_employee = CensusEmployee.by_benefit_group_assignment_ids([bga_id]).first

      if census_employee.nil?
        puts "No census employee was found with given benefit group assignment id" unless Rails.env.test?
      else
        benefit_group_assignment = census_employee.benefit_group_assignments.find(bga_id)
        benefit_group_assignment.make_active if benefit_group_assignment
      end
    rescue => e
      puts "Unable to Activate Benefit Group Assignment because of Error: #{e}, Backtrace: #{e.backtrace}" unless Rails.env.test?
    end
  end
end
