# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")
require 'csv'

module HbxReports
  class ShopEnrollmentReport < MongoidMigrationTask
    def migrate
      purchase_date_range = determine_date_range
      FileUtils.mkdir_p("hbx_report")

      qs = setup_query_pipeline(purchase_date_range)
      glue_list = load_glue_list
      enrollment_ids = get_enrollment_ids(qs)
      field_names = field_names_for_report

      generate_csv_report(enrollment_ids, field_names, glue_list)
      puts "Shop Enrollment Report Generated" unless Rails.env.test?
    end

    private

    # Determine the date range for the report
    def determine_date_range
      if ENV['purchase_date_start'].blank? && ENV['purchase_date_end'].blank?
        # Purchase dates are from 10 weeks to todays date
        start_date = (Time.now - 2.month - 8.days).beginning_of_day
        end_date = Time.now.end_of_day
      else
        start_date = Time.strptime(ENV.fetch('purchase_date_start', nil), '%m/%d/%Y').beginning_of_day
        end_date = Time.strptime(ENV.fetch('purchase_date_end', nil), '%m/%d/%Y').end_of_day
      end
      { start: start_date, end: end_date }
    end

    # Set up the query pipeline
    def setup_query_pipeline(date_range)
      qs = Queries::PolicyAggregationPipeline.new
      qs.filter_to_shopping_completed
      qs.eliminate_family_duplicates
      qs.add({
               "$match" => {
                 "policy_purchased_at" => {
                   "$gte" => date_range[:start],
                   "$lte" => date_range[:end]
                 }
               }
             })
      qs
    end

    # Load glue list if file exists
    def load_glue_list
      File.read("all_glue_policies.txt").split("\n").map(&:strip) if File.exist?("all_glue_policies.txt")
    end

    # Get enrollment IDs from the query results
    def get_enrollment_ids(query_service)
      query_service.evaluate.inject([]) do |result, r|
        result << r['hbx_id']
        result
      end
    end

    # Define field names for the CSV report
    def field_names_for_report
      ['Employer ID', 'Employer FEIN', 'Employer Name', 'Employer Plan Year Start Date',
       'Plan Year State', 'Employer State', 'Enrollment Group ID',
       'Enrollment Purchase Date/Time', 'Coverage Start Date', 'Enrollment State',
       'Subscriber HBX ID', 'Subscriber First Name','Subscriber Last Name', 'Subscriber SSN',
       'Plan HIOS Id', 'Employer Rating Area', 'Is PVP Plan',
       'Covered lives on the enrollment', 'Enrollment Reason', 'In Glue']
    end

    # Generate the CSV report
    def generate_csv_report(enrollment_ids, field_names, glue_list)
      file_name = "#{Rails.root}/hbx_report/shop_enrollment_report.csv"
      CSV.open(file_name, "w", force_quotes: true) do |csv|
        csv << field_names
        enrollment_ids.each do |id|
          hbx_enrollment = HbxEnrollment.by_hbx_id(id).first
          begin
            enrollment_data = get_enrollment_data(hbx_enrollment, id, glue_list)
            csv << enrollment_data if enrollment_data
          rescue StandardError => e
            puts "Could not add the hbx_enrollment's information on to the CSV, because #{e.inspect}" unless Rails.env.test?
          end
        end
      end
    end

    # Get enrollment data for a single enrollment
    def get_enrollment_data(hbx_enrollment, id, glue_list)
      employer_profile = hbx_enrollment.employer_profile

      # Get enrollment reason
      enrollment_reason = case hbx_enrollment.enrollment_kind
                          when "special_enrollment"
                            hbx_enrollment.special_enrollment_period.qualifying_life_event_kind.reason
                          when "open_enrollment"
                            hbx_enrollment.eligibility_event_kind
                          end

      # Get employer info
      employer_id = employer_profile.hbx_id
      fein = employer_profile.fein
      legal_name = employer_profile.legal_name

      # Get plan year info
      plan_year = hbx_enrollment.sponsored_benefit_package.benefit_application
      rating_area = plan_year.recorded_rating_area.exchange_provided_code
      plan_year_start = plan_year.start_on.to_s
      plan_year_state = plan_year.aasm_state
      employer_profile_aasm = plan_year.benefit_sponsorship.aasm_state

      # Get enrollment info
      eg_id = id
      purchase_time = hbx_enrollment.created_at
      coverage_start = hbx_enrollment.effective_on
      enrollment_state = hbx_enrollment.aasm_state

      # Get coverage and plan info
      subscriber = hbx_enrollment.subscriber
      covered_lives = hbx_enrollment.hbx_enrollment_members.size
      plan_hios_id = hbx_enrollment.product.hios_id
      is_pvp = hbx_enrollment.product.is_pvp_in_rating_area(rating_area, plan_year.start_on.to_date)

      # Initialize subscriber info
      subscriber_hbx_id = nil
      first_name = nil
      last_name = nil
      subscriber_ssn = nil

      # Get subscriber info if available
      if subscriber.present? && subscriber.person.present?
        person = subscriber.person
        subscriber_hbx_id = subscriber.hbx_id
        first_name = person.first_name
        last_name = person.last_name
        subscriber_ssn = person.ssn
      end

      # Check if in glue
      in_glue = glue_list.present? && glue_list.include?(id)

      # Return enrollment data array
      [
        employer_id, fein, legal_name, plan_year_start, plan_year_state,
        employer_profile_aasm, eg_id, purchase_time, coverage_start, enrollment_state,
        subscriber_hbx_id, first_name, last_name, subscriber_ssn, plan_hios_id,
        rating_area, is_pvp, covered_lives, enrollment_reason, in_glue
      ]
    end
  end
end