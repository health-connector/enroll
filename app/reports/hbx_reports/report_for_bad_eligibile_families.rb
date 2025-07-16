# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")
require 'csv'

module HbxReports
  class ReportForBadEligibileFamilies < MongoidMigrationTask
    def migrate
      setup_directory_and_file
      field_names = field_names_for_report

      CSV.open(@file_name, "w", force_quotes: true) do |csv|
        csv << field_names
        process_families(csv)
        log_completion
      end
    end

    private

    # Set up directory and file name
    def setup_directory_and_file
      FileUtils.mkdir_p("hbx_report")
      @file_name = "#{Rails.root}/hbx_report/report_for_bad_eligibile_families.csv"
    end

    # Define CSV field names
    def field_names_for_report
      %w[
        Assistance_applicable_year
        Family_e_case_id
        PrimaryPerson_FN
        PrimaryPerson_LN
        PrimaryPerson_Hbx_ID
        Dependent_FN
        Dependent_LN
        PDC_IA
        PDC_Medicaid
      ]
    end

    # Process eligible families
    def process_families(csv)
      Family.all_eligible_for_assistance.each do |family|
        process_family(family, csv)
      rescue StandardError => e
        puts "Bad Family Record, error: #{e}" unless Rails.env.test?
      end
    end

    # Process a single family record
    def process_family(family, csv)
      primary_person = family.primary_applicant.person
      tax_household = family.active_household.latest_active_tax_household
      eligibility_determination = tax_household.latest_eligibility_determination
      members = tax_household.tax_household_members

      if aptc_eligible_with_no_ia_members?(eligibility_determination, members)
        process_aptc_eligible_family(family, tax_household, primary_person, members, csv)
      else
        process_members_with_conflict(family, tax_household, primary_person, members, csv)
      end
    end

    # Check if the household is APTC eligible but has no IA-eligible members
    def aptc_eligible_with_no_ia_members?(eligibility_determination, members)
      (eligibility_determination.max_aptc.to_f > 0.0 ||
       eligibility_determination.csr_eligibility_kind != "csr_100") &&
        !members.map(&:is_ia_eligible).include?(true)
    end

    # Process an APTC-eligible family with members who aren't IA eligible
    def process_aptc_eligible_family(family, tax_household, primary_person, members, csv)
      members.each do |tax_household_member|
        add_member_to_csv(
          tax_household,
          family,
          primary_person,
          tax_household_member,
          csv
        )
      end
      log_primary_person(primary_person)
    end

    # Process members with conflicting eligibility statuses
    def process_members_with_conflict(family, tax_household, primary_person, members, csv)
      members.each do |tax_household_member|
        next unless tax_household_member.is_ia_eligible && tax_household_member.is_medicaid_chip_eligible

        add_member_to_csv(
          tax_household,
          family,
          primary_person,
          tax_household_member,
          csv
        )
        log_primary_person(primary_person)
      end
    end

    # Add a tax household member to the CSV
    def add_member_to_csv(tax_household, family, primary_person, tax_household_member, csv)
      csv << [
        tax_household.effective_starting_on.year,
        family.e_case_id,
        primary_person.first_name,
        primary_person.last_name,
        primary_person.hbx_id,
        tax_household_member.person.first_name,
        tax_household_member.person.last_name || tax_household_member.last_name,
        tax_household_member.is_ia_eligible,
        tax_household_member.is_medicaid_chip_eligible
      ]
    end

    # Log primary person's hbx_id
    def log_primary_person(primary_person)
      puts "Primary_Person_hbx_id: #{primary_person.hbx_id}" unless Rails.env.test?
    end

    # Log completion message
    def log_completion
      puts "End of the report" unless Rails.env.test?
    end
  end
end
