require 'csv'

# The idea behind this report is to get a list of all shop enrollments which are currently in EA. 
# Steps
# 1) You need to pull a list of enrollments from glue (bundle exec rails r script/queries/print_all_policy_ids > all_glue_policies.txt -e production)
# 2) Place that file into the Enroll Root directory. 
# 3) Run the below rake task
# RAILS_ENV=production bundle exec rake reports:shop_enrollment_report purchase_date_start='06/01/2018' purchase_date_end='06/10/2018'

namespace :reports do 

  desc "SHOP Enrollment Recon Report"
  task :shop_enrollment_report => :environment do
    purchase_date_start = Time.strptime(ENV['purchase_date_start'],'%m/%d/%Y').beginning_of_day 
    purchase_date_end = Time.strptime(ENV['purchase_date_end'],'%m/%d/%Y').end_of_day

    Dir.mkdir("hbx_report") unless File.exists?("hbx_report")

    qs = Queries::PolicyAggregationPipeline.new
    qs.eliminate_family_duplicates

    qs.add({ "$match" => {"policy_purchased_at" => {"$gte" => purchase_date_start, "$lte" => purchase_date_end}}})
    glue_list = File.read("all_glue_policies.txt").split("\n").map(&:strip)

    enrollment_ids = []

    qs.evaluate.each do |r|
      enrollment_ids << r['hbx_id']
    end

    enrollment_ids_final = []
    enrollment_ids.each{|id| (enrollment_ids_final << id) unless HbxEnrollment.by_hbx_id(id).first.aasm_state == 'shopping'}

    field_names = ['Employer ID', 'Employer FEIN', 'Employer Name', 'Employer Plan Year Start Date', 'Plan Year State', 'Employer State', 'Enrollment Group ID', 
               'Enrollment Purchase Date/Time', 'Coverage Start Date', 'Enrollment State', 'Subscriber HBX ID', 'Subscriber First Name','Subscriber Last Name', 'Subscriber SSN', 'Plan HIOS Id', 'Covered lives on the enrollment']

    CSV.open("#{Rails.root}/hbx_report/#{purchase_date_start.strftime('%Y%m%d')}_employer_purchase_date_start_enrollments_to_#{purchase_date_end.strftime('%Y%m%d')}_employer_purchase_date_end_enrollments.csv","w") do |csv|
      csv << field_names
      enrollment_ids_final.each do |id|
        hbx_enrollment = HbxEnrollment.by_hbx_id(id).first
        employer_profile = hbx_enrollment.employer_profile
        employer_id = employer_profile.hbx_id
        fein = employer_profile.fein
        legal_name = employer_profile.legal_name
        plan_year = hbx_enrollment.benefit_group.plan_year
        plan_year_start = plan_year.start_on.to_s
        plan_year_state = plan_year.aasm_state
        employer_profile_aasm = employer_profile.aasm_state
        eg_id = id
        purchase_time = hbx_enrollment.created_at
        coverage_start = hbx_enrollment.effective_on
        enrollment_state = hbx_enrollment.aasm_state 
        subscriber = hbx_enrollment.subscriber
        covered_lives = hbx_enrollment.hbx_enrollment_members.size
        plan_hios_id = hbx_enrollment.plan.hios_id
        if subscriber.present? && subscriber.person.present?
          subscriber_hbx_id = subscriber.hbx_id
          first_name = subscriber.person.first_name
          last_name = subscriber.person.last_name
          subscriber_ssn = subscriber.person.ssn
        end
        csv << [employer_id,fein,legal_name,plan_year_start,plan_year_state,employer_profile_aasm,eg_id,purchase_time,coverage_start,enrollment_state,subscriber_hbx_id,first_name,last_name,subscriber_ssn,plan_hios_id,covered_lives]
      end
    end
  end
end