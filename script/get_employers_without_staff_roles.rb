require 'csv'

field_names  = %w[org_legal_name org_fein employer_id]
file_name = "#{Rails.root}/employers_without_staff_roles.csv"

CSV.open(file_name, 'w', force_quotes: true) do |csv|
  csv << field_names
  counter = 0
  organizations = ::BenefitSponsors::Organizations::Organization.employer_profiles
  organizations.each do |organization|
    begin
      profile_id = organization.employer_profile.id.to_s
      staff_roles = Person.where(:employer_staff_roles => { '$elemMatch' => { :benefit_sponsor_employer_profile_id => BSON::ObjectId(profile_id), :aasm_state.ne => :is_closed } })
      if staff_roles.blank?
        csv << [ organization.legal_name, organization.fein, profile_id]
        counter += 1
      end
    rescue Exception => e
      puts "Error for organization with fein: #{organization.fein} with error message: #{e.message}" unless Rails.env.test?
    end
  end
  puts "Total number of employers without Staff Roles are #{counter}" unless Rails.env.test?
end