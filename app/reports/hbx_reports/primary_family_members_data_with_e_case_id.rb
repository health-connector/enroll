# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")
require 'csv'

module HbxReports
  class PrimaryFamilyMembersDataWithECaseId < MongoidMigrationTask
    def migrate
      field_names = field_names_for_report
      file_name = "#{Rails.root}/public/primary_family_members_data_with_e_case_id.csv"
      count = 0

      CSV.open(file_name, "w", force_quotes: true) do |csv|
        csv << field_names
        families = Family.where(:e_case_id.nin => ["", nil])

        families.all.each do |family|
          count = process_family(family, csv, count)
        end
      end

      log_completion(count)
    end

    private

    # Get field names for the CSV report
    def field_names_for_report
      %w(
        Integrated_Case_ID_(e_case_id)
        Subscriber_FN
        Subscriber_LN
        HBX_ID
        SSN
        DOB
        Gender
        Primary_Person_Record_Create_Date
        Type
        Active_Enrollment
        Applied_aptc_amount
        CSR_Enrollment
      )
    end

    # Process each family and its members
    def process_family(family, csv, count)
      person = family.primary_family_member.person
      aptc, csr = get_aptc_and_csr(family)

      # Add primary family member to CSV
      member_data = {
        family: family,
        person: person,
        type: "Primary",
        aptc: aptc,
        csr: csr
      }
      add_to_csv(csv, member_data)

      # Add dependents to CSV
      process_dependents(family, csv, aptc, csr)

      count += 1
      count
    rescue StandardError => e
      puts "Bad Family record with id: #{family.id}, error: #{e.message}" unless Rails.env.test?
      count
    end

    # Get APTC amount and CSR status
    def get_aptc_and_csr(family)
      aptc = 0
      csr = "No"

      if family.has_aptc_hbx_enrollment?
        aptc = family.latest_household.hbx_enrollments.active.order("created_at DESC").first.applied_aptc_amount.to_f
        csr = "Yes" if family.active_household.hbx_enrollments.with_aptc.enrolled_and_renewing.any? { |enrollment| enrollment.plan.is_csr? }
      end

      [aptc, csr]
    end

    # Process dependent family members
    def process_dependents(family, csv, aptc, csr)
      family.dependents.each do |dependent|
        dependent_person = dependent.person
        member_data = {
          family: family,
          person: dependent_person,
          type: "Dependent",
          aptc: aptc,
          csr: csr
        }
        add_to_csv(csv, member_data)
      end
    end

    # Add a person to the CSV using a single data parameter
    def add_to_csv(csv, data)
      csv << [
        data[:family].e_case_id,
        data[:person].first_name,
        data[:person].last_name,
        data[:person].hbx_id,
        data[:person].ssn,
        data[:person].dob,
        data[:person].gender,
        data[:person].created_at.to_date,
        data[:type],
        Person.person_has_an_active_enrollment?(data[:person]) ? "Yes" : "No",
        data[:aptc],
        data[:csr]
      ]
    end

    # Log completion message with statistics
    def log_completion(count)
      puts "Total number of families with e_case_id: #{count}" unless Rails.env.test?
    end
  end
end