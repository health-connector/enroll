require 'csv'
require File.join(Rails.root, "lib/mongoid_migration_task")
class NewHireEffectiveOnReport< MongoidMigrationTask
	def migrate
		organization_headers = ['Employer Legal Name', 'Employer FEIN', 'Employer Plan Year Start Date', 'Employer HBX ID']
    	employee_headers = ['Employer Legal Name', 'Employer FEIN', 'Employer Plan Year Start Date', 'Employer HBX ID', 'EE First Name', 'EE Last Name', 'EE HBX ID', 'Enrollment Policy ID', 'Enrollment HIOS ID', 'Enrollment Carrier Name', 'Enrollment Plan Name', 'Enrollment Submitted On Date', 'EE Effective date of coverage', 'EE Date Of Hire','EE Added to roster date']
    	organization_report = "#{Rails.root}/organization_report.csv"
    	employee_report = "#{Rails.root}/employee_report.csv"
    	CSV.open(organization_report, "w",:force_quotes=> true) do |csv_org|
      	csv_org << organization_headers
      	CSV.open(employee_report, "w",:force_quotes=> true) do |csv_emp|
        csv_emp << employee_headers
				organizations = Organization.where(
					:"employer_profile.profile_source" => "conversion",
				  :"employer_profile.plan_years" => {
				  	:"$elemMatch" => {
				  		:"start_on" => {:"$gte" => Date.new(2018,1,01), :"$lte" => Date.new(2018,4,01)}
				  	}
					},
					:"employer_profile.plan_years.benefit_groups.effective_on_offset" => 30
				)
				organizations.each do |org|
					profile = org.employer_profile
					effected_py = profile.plan_years.where(
						:"start_on" => {:"$gte" => Date.new(2018,1,01), :"$lte" => Date.new(2018,4,01)}
					).first

					csv_org << ["#{org.employer_profile.legal_name}", "#{org.fein}", "#{effected_py.start_on}", "#{org.employer_profile.hbx_id}"]
					
					effected_bg_ids = effected_py.benefit_groups.where(:"effective_on_offset" => 30).map(&:id)

					families = Family.where(
						:"households.hbx_enrollments" => {
							:"$elemMatch" => {
								:"benefit_group_id".in => effected_bg_ids,
								:"effective_on".gt => effected_py.start_on,
								:"plan_id".ne => nil
				 			}
						}
					)
					families.each do |family|	
						family.active_household.hbx_enrollments.where(
							:"benefit_group_id".in => effected_bg_ids,
							:"effective_on".gt => effected_py.start_on
						).each do |enrollment|
							employee_role = enrollment.employee_role
							person = employee_role.person
							plan = enrollment.plan
							csv_emp << ["#{org.employer_profile.legal_name}", "#{org.fein}", "#{effected_py.start_on}", "#{org.employer_profile.hbx_id}","#{person.first_name}","#{person.last_name}","#{person.hbx_id}","#{enrollment.hbx_id}","#{plan.hios_id}","#{plan.name}","#{plan.carrier_profile.legal_name}","#{enrollment.submitted_at}","#{enrollment.effective_on}","#{employee_role.hired_on}","#{employee_role.census_employee.created_at}"]
						end
					end
				end
			end
		end
	end
end