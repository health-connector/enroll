# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")
require 'csv'

module HbxReports
  class OutstandingMonthlyEnrollments < MongoidMigrationTask
    include Config::AcaHelper

    def get_enrollment_ids(benefit_applications)
      benefit_applications.inject([]) do |ids, ba|
        families = Family.unscoped.where(:"households.hbx_enrollments" =>
          { :$elemMatch =>
            {
              :sponsored_benefit_package_id => { "$in" => ba.benefit_packages.pluck(:_id) },
              :aasm_state => { "$nin" => %w[coverage_canceled shopping coverage_terminated] }
            }})
        id_list = ba.benefit_packages.collect(&:_id).uniq
        enrs = families.inject([]) do |enrollments, family|
          enrollments << family.active_household.hbx_enrollments.where(:sponsored_benefit_package_id.in => id_list).enrolled_and_renewing.to_a
          enrollments.flatten.compact.uniq
        end
        ids += enrs.map(&:hbx_id)
        ids.flatten.compact.uniq
      end
    end

    # Calculate date range for quiet period
    def quiet_period_range(benefit_application, effective_on)
      start_on = benefit_application.open_enrollment_period.max.to_date
      end_on = if benefit_application.predecessor.present?
                 benefit_application.renewal_quiet_period_end(effective_on)
               else
                 benefit_application.initial_quiet_period_end(effective_on)
               end
      (start_on..end_on)
    end

    def migrate
      effective_on = Date.strptime(ENV.fetch('start_date', nil), '%m/%d/%Y')
      file_name = "#{Rails.root}/hbx_report/#{effective_on.strftime('%Y%m%d')}_employer_enrollments_#{Time.now.strftime('%Y%m%d%H%M')}.csv"
      FileUtils.mkdir_p("hbx_report")

      field_names = csv_field_names
      glue_list = load_glue_list

      CSV.open(file_name, "w") do |csv|
        csv << field_names
        benefit_sponsorships = load_benefit_sponsorships(effective_on)
        benefit_applications = get_benefit_applications(benefit_sponsorships, effective_on)
        enrollment_ids = get_enrollment_ids(benefit_applications)

        process_enrollments(enrollment_ids, csv, glue_list, effective_on)

        publish_report(file_name) if Rails.env.production?
        log_completion(file_name)
      end
    end

    # Load benefit sponsorships based on effective date
    def load_benefit_sponsorships(effective_on)
      BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
        { "benefit_applications" =>
          { "$elemMatch" => { "effective_period.min" => effective_on } }}
      )
    end

    # Get benefit applications for the effective date
    def get_benefit_applications(benefit_sponsorships, effective_on)
      benefit_sponsorships.to_a.flat_map(&:benefit_applications).to_a.select do |ba|
        ba.effective_period.min == effective_on
      end
    end

    # Load glue list if file exists
    def load_glue_list
      File.read("all_glue_policies.txt").split("\n").map(&:strip) if File.exist?("all_glue_policies.txt")
    end

    # Process all enrollments and write to CSV
    def process_enrollments(enrollment_ids, csv, glue_list, effective_on)
      enrollment_ids.each do |id|
        hbx_enrollment = HbxEnrollment.by_hbx_id(id).first
        enrollment_data = enrollment_data_for_csv(hbx_enrollment, id, glue_list, effective_on)
        csv << enrollment_data if enrollment_data
      rescue StandardError => e
        puts "#{id} - #{e.inspect}" unless Rails.env.test?
        next
      end
    end

    # Get enrollment data formatted for CSV
    def enrollment_data_for_csv(hbx_enrollment, id, glue_list, effective_on)
      enrollment_reason = get_enrollment_reason(hbx_enrollment)

      # Extract common data
      enrollment_basics = extract_enrollment_basics(hbx_enrollment)
      sponsorship_data = extract_sponsorship_data(hbx_enrollment)
      benefit_data = extract_benefit_data(hbx_enrollment)
      product_data = extract_product_data(hbx_enrollment)
      subscriber_data = extract_subscriber_data(hbx_enrollment)
      flag_data = extract_flag_data(hbx_enrollment, id, glue_list, effective_on)

      # Combine all data
      [
        sponsorship_data[:employer_id],
        sponsorship_data[:fein],
        sponsorship_data[:legal_name],
        benefit_data[:oe_start],
        benefit_data[:oe_end],
        benefit_data[:start_date],
        benefit_data[:state],
        enrollment_basics[:covered_lives],
        enrollment_reason,
        sponsorship_data[:sponsorship_state],
        benefit_data[:initial_renewal],
        benefit_data[:binder_paid],
        id,
        product_data[:carrier],
        product_data[:title],
        product_data[:hios_id],
        product_data[:super_group_id],
        enrollment_basics[:purchase_time],
        enrollment_basics[:coverage_start],
        enrollment_basics[:state],
        subscriber_data[:hbx_id],
        subscriber_data[:first_name],
        subscriber_data[:last_name],
        flag_data[:in_glue],
        flag_data[:quiet_period]
      ]
    end

    # Get enrollment reason
    def get_enrollment_reason(hbx_enrollment)
      case hbx_enrollment.enrollment_kind
      when "special_enrollment"
        hbx_enrollment.special_enrollment_period.qualifying_life_event_kind.reason
      when "open_enrollment"
        hbx_enrollment.eligibility_event_kind
      end
    end

    # Extract basic enrollment data
    def extract_enrollment_basics(hbx_enrollment)
      {
        covered_lives: hbx_enrollment.hbx_enrollment_members.size,
        purchase_time: hbx_enrollment.created_at,
        coverage_start: hbx_enrollment.effective_on,
        state: hbx_enrollment.aasm_state
      }
    end

    # Extract sponsorship data
    def extract_sponsorship_data(hbx_enrollment)
      benefit_sponsorship = hbx_enrollment.benefit_sponsorship
      {
        employer_id: benefit_sponsorship.hbx_id,
        fein: benefit_sponsorship.organization.fein,
        legal_name: benefit_sponsorship.organization.legal_name,
        sponsorship_state: benefit_sponsorship.aasm_state
      }
    end

    # Extract benefit application data
    def extract_benefit_data(hbx_enrollment)
      benefit_application = hbx_enrollment.sponsored_benefit_package.benefit_application
      {
        oe_start: benefit_application.open_enrollment_period.min,
        oe_end: benefit_application.open_enrollment_period.max,
        start_date: benefit_application.effective_period.min.to_s,
        state: benefit_application.aasm_state,
        initial_renewal: benefit_application.predecessor.present? ? "renewal" : "initial",
        binder_paid: benefit_application.binder_paid?
      }
    end

    # Extract product data
    def extract_product_data(hbx_enrollment)
      product = begin
        hbx_enrollment.product
      rescue StandardError => e
        puts "Error getting product: #{e.message}" unless Rails.env.test?
        nil
      end

      {
        carrier: begin
          product.try(:issuer_profile).try(:legal_name)
        rescue StandardError => e
          puts "Error getting carrier: #{e.message}" unless Rails.env.test?
          ""
        end,
        title: product.try(:title),
        hios_id: product.try(:hios_id),
        super_group_id: product.try(:issuer_assigned_id)
      }
    end

    # Extract subscriber data
    def extract_subscriber_data(hbx_enrollment)
      subscriber = hbx_enrollment.subscriber
      data = { hbx_id: nil, first_name: nil, last_name: nil }

      if subscriber.present? && subscriber.person.present?
        data[:hbx_id] = subscriber.hbx_id
        data[:first_name] = subscriber.person.first_name
        data[:last_name] = subscriber.person.last_name
      end

      data
    end

    # Extract flag data
    def extract_flag_data(hbx_enrollment, id, glue_list, effective_on)
      benefit_application = hbx_enrollment.sponsored_benefit_package.benefit_application
      qp = quiet_period_range(benefit_application, effective_on)

      {
        in_glue: glue_list.present? && glue_list.include?(id),
        quiet_period: qp.include?(hbx_enrollment.created_at)
      }
    end

    # Publish report to S3 in production
    def publish_report(file_name)
      pubber = Publishers::Legacy::OutstandingMonthlyEnrollmentsReportPublisher.new
      pubber.publish URI.join("file://", file_name)
    end

    # Log completion message
    def log_completion(file_name)
      puts 'Report has been successfully generated in the hbx_report directory!' if File.exist?(file_name) && !Rails.env.test?
    end

    # Define CSV field names
    def csv_field_names
      [
        "Employer ID", "Employer FEIN", "Employer Name", "Open Enrollment Start",
        "Open Enrollment End", "Employer Plan Year Start Date", "Plan Year State",
        "Covered Lives", "Enrollment Reason", "Employer State", "Initial/Renewal?",
        "Binder Paid?", "Enrollment Group ID", "Carrier", "Plan", "Plan Hios ID",
        "Super Group ID", "Enrollment Purchase Date/Time", "Coverage Start Date",
        "Enrollment State", "Subscriber HBX ID", "Subscriber First Name",
        "Subscriber Last Name", "Policy in Glue?", "Quiet Period?"
      ]
    end
  end
end
