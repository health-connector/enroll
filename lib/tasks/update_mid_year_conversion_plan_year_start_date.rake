namespace :update do
  desc "cache premiums plan for fast group fetch"
  task :mid_year_conversion_plan_year_start_date => :environment do
    organizations = Organization.where(:"employer_profile.mid_year_conversion" => "true")
    organizations.each do |org|
      plan_year = org.employer_profile.plan_years.first
      plan_year.is_conversion = false
      plan_year.start_on = Date.strptime(ENV['start_date'].to_s, "%m/%d/%Y")
      plan_year.save(validate: false)
      plan_year.hbx_enrollments.each{|en| en.update(external_enrollment: false)}
    end
  end
end