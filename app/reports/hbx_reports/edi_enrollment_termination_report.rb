# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")
require 'csv'

module HbxReports
  class EdiEnrollmentTerminationReport < MongoidMigrationTask
    include Config::AcaHelper

    def migrate
      families = families_to_report
      field_names = field_names_for_report
      processed_count = 0
      file_name = fetch_file_format('edi_enrollment_termination_report', 'EDIENROLLMENTTERMINATION')

      CSV.open(file_name, "w", force_quotes: true) do |csv|
        csv << field_names
        process_families(families, csv, processed_count)

        publish_file(file_name) if Rails.env.production?

        log_completion(file_name, processed_count)
      end
    end

    # Processes all families and writes their data to the CSV
    def process_families(families, csv, processed_count)
      families.each do |family|
        next unless family_eligible?(family)

        hbx_enrollments = family.active_household.hbx_enrollments.select { |enrollment| enrollment_for_report?(enrollment) }
        hbx_enrollment_members = hbx_enrollments.flat_map(&:hbx_enrollment_members)
        process_enrollment_members(family, hbx_enrollment_members, csv, processed_count)
      end
      processed_count
    end

    # Determines if a family is eligible for inclusion in the report
    def family_eligible?(family)
      family.try(:primary_family_member).try(:person).try(:active_employee_roles).try(:any?) ||
        family.try(:primary_family_member).try(:person).try(:consumer_role).try(:present?)
    end

    # Process enrollment members and add them to the CSV
    def process_enrollment_members(family, hbx_enrollment_members, csv, processed_count)
      hbx_enrollment_members.each do |hbx_enrollment_member|
        add_member_to_csv(family, hbx_enrollment_member, csv) if hbx_enrollment_member
        processed_count += 1
      end
      processed_count
    end

    # Add a single member's data to the CSV
    def add_member_to_csv(family, hbx_enrollment_member, csv)
      person = hbx_enrollment_member.person
      enrollment = hbx_enrollment_member.hbx_enrollment
      primary_person = family.primary_family_member.person
      employer = enrollment.try(:employer_profile)
      census_employee = person.try(:employee_roles).try(:first).try(:census_employee)

      csv << [
          person.hbx_id,
          person.first_name,
          person.last_name,
          employer ? employer.legal_name : "IVL",
          employer ? employer.fein : "IVL",
          census_employee ? census_employee.aasm_state : "IVL",
          primary_person.hbx_id,
          primary_person.first_name,
          primary_person.last_name,
          enrollment.kind,
          enrollment.product.issuer_profile.legal_name,
          enrollment.product.name,
          enrollment.coverage_kind,
          enrollment.product.hios_id,
          enrollment.hbx_id,
          enrollment.aasm_state,
          enrollment.effective_on,
          enrollment.terminated_on,
          primary_person.find_relationship_with(person),
          transition_date(enrollment)
      ]
    end

    # Publish file to S3 in production
    def publish_file(file_name)
      pubber = Publishers::Legacy::EdiEnrollmentTerminationReportPublisher.new
      pubber.publish URI.join("file://", file_name)
    end

    # Log completion message with statistics
    def log_completion(file_name, processed_count)
      puts "For date #{date_of_termination}, total terminated hbx_enrollments count #{processed_count} and output file is: #{file_name}" unless Rails.env.test?
    end

    # Define field names for the CSV report
    def field_names_for_report
      %w[
        Enrolled_Member_HBX_ID
        Enrolled_Member_First_Name
        Enrolled_Member_Last_Name
        Employer_Legal_Name
        Employer_Fein
        Employee_Census_State
        Primary_Member_HBX_ID
        Primary_Member_First_Name
        Primary_Member_Last_Name
        Market_Kind
        Carrier_Legal_Name
        Plan_Name
        Coverage_Type
        HIOS_ID
        Policy_ID
        Enrollment_State
        Effective_Start_Date
        Coverage_End_Date
        Member_relationship
        Coverage_state_occured
      ]
    end

    # Returns families with terminated or termination pending enrollments
    def families_to_report
      Family.where(:"households.hbx_enrollments" =>
                       {:$elemMatch =>
                            {'$or' =>
                                 [{:aasm_state => "coverage_terminated"},
                                  {:aasm_state => "coverage_termination_pending"}],
                             "workflow_state_transitions.transition_at" => date_of_termination}})
    end

    def date_of_termination
      start_date = ENV['start_date'] ? Date.strptime(ENV['start_date'], '%Y-%m-%d').beginning_of_day : Date.yesterday.beginning_of_day
      end_date = ENV['end_date'] ? Date.strptime(ENV['end_date'], '%Y-%m-%d').end_of_day : Date.yesterday.end_of_day
      start_date..end_date
    end

    def enrollment_for_report?(enrollment)
      enrollment_state?(enrollment) && enrollment_date?(enrollment)
    end

    def enrollment_state?(enrollment)
      enrollment.coverage_terminated? || enrollment.coverage_termination_pending?
    end

    def enrollment_date?(enrollment)
      date_of_termination.cover?(transition_date(enrollment).try(:strftime, '%Y-%m-%d'))
    end

    def transition_date(enrollment)
      enrollment.workflow_state_transitions.try(:first).try(:transition_at)
    end
  end
end
