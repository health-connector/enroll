# This rake task will trigger SEP denial notice to employees
# Running the task with arguments from command line
# Ex: rake notice:trigger_sep_denial_notice_to_employees file_name="name_of_the_file"
namespace :notice do
  desc "Trigger SEP denial notice to employees"
  task :trigger_sep_denial_notice_to_employees => :environment do |task, args|
    file_name = ENV['file_name']
    event_name = "employee_notice_for_sep_denial"
    file_path = "#{Rails.root}/#{file_name}.csv"
    CSV.foreach("#{file_path}", headers: true) do |row|
      person = Person.where(hbx_id: row["hbx_id"]).first
      qle = QualifyingLifeEventKind.find(row["qle_id"])
      today = TimeKeeper.date_of_record
      qle_date = Date.strptime(row["qle_date"], "%m/%d/%Y")
      reporting_deadline = qle_date > today ? today : qle_date + 30.days
      employee_role = person.active_employee_roles.first
      if employee_role && employee_role.census_employee
        begin
          employee_role.census_employee.trigger_model_event(:employee_notice_for_sep_denial, {qle_title: qle.title, qle_reporting_deadline: reporting_deadline.strftime("%m/%d/%Y"), qle_event_on: qle_date.strftime("%m/%d/%Y")})
          puts "Notice Triggered for hbx_id #{row['hbx_id']}"
        rescue Exception => e
          puts "Error trigger #{event_name} notice to hbx_id #{row['hbx_id']} due to #{e}"
        end
      end
    end
  end
end