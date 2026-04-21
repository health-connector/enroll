# frozen_string_literal: true

# Generates a summary of communication preference and language preference
# elections for active SHOP employers (ERs) and active employees (EEs).
#
# The report contains three sections:
#   1. EE Communication Preference — contact_method on EmployeeRole
#   2. EE Language Preference — language_preference on EmployeeRole
#   3. EE Preference x Language cross-tab
#   4. ER Communication Preference — contact_method on EmployerProfile / BenefitSponsors profile
#      (ERs do not store a language preference)
#
# Usage:
#   RAILS_ENV=production bundle exec rake reports:communication:communication_language_summary

require 'csv'

namespace :reports do
  namespace :communication do
    desc 'Generate communication preference and language breakdown for active ERs and active EEs (SHOP only)'
    task communication_language_summary: :environment do
      file_name = "#{Rails.root}/public/communication_language_summary_#{TimeKeeper.date_of_record.strftime('%m_%d_%Y')}.csv"
      preferences = ['Paper', 'Electronic', 'Paper and Electronic', 'Other or Blank'].freeze
      languages   = ['English', 'Spanish', 'Amharic', 'Other or Blank'].freeze

      # --- EE counters ---
      ee_pref_counts = Hash.new(0)
      ee_lang_counts = Hash.new(0)
      ee_matrix      = Hash.new { |h, k| h[k] = Hash.new(0) }
      ee_total       = 0
      ee_error_count = 0

      # --- ER counters ---
      er_pref_counts = Hash.new(0)
      er_total       = 0
      er_error_count = 0

      puts "Starting communication preference report at #{Time.now}" unless Rails.env.test?

      # ----------------------------------------------------------------
      # Section 1 — EEs: iterate persons with active employee_roles
      # ----------------------------------------------------------------
      Person.all_employee_roles.active.no_timeout.each do |person|
        person.active_employee_roles.each do |employee_role|

          employer = employee_role.employer_profile
          next unless employer.present? && er_active_employer?(employer)

          pref = communication_preference_bucket(employee_role.contact_method)
          lang = language_preference_bucket(employee_role.language_preference)

          ee_pref_counts[pref] += 1
          ee_lang_counts[lang] += 1
          ee_matrix[pref][lang] += 1
          ee_total += 1
        rescue StandardError => e
          ee_error_count += 1
          puts "EE error on employee_role #{employee_role&.id} (person #{person&.hbx_id}): #{e.message}" unless Rails.env.test?

        end
      end

      # ----------------------------------------------------------------
      # Section 2 — ERs: iterate active new-style employer profiles
      # New-style contact_method is a Symbol (:paper_and_electronic,
      # :paper_only, :electronic_only); old-style is a String.
      # ----------------------------------------------------------------
      BenefitSponsors::Organizations::Organization.employer_profiles.no_timeout.each do |org|
        employer_profile = org.employer_profile
        next unless employer_profile.present? && er_active_employer?(employer_profile)

        pref = communication_preference_bucket(employer_profile.contact_method)
        er_pref_counts[pref] += 1
        er_total += 1
      rescue StandardError => e
        er_error_count += 1
        puts "ER error on org #{org&.hbx_id}: #{e.message}" unless Rails.env.test?
      end

      # Also cover legacy EmployerProfile records not yet migrated to BenefitSponsors
      Organization.exists(employer_profile: true).no_timeout.each do |org|
        employer_profile = org.employer_profile
        next unless employer_profile.present? && employer_profile.respond_to?(:has_active_state?) && employer_profile.has_active_state?

        pref = communication_preference_bucket(employer_profile.contact_method)
        er_pref_counts[pref] += 1
        er_total += 1
      rescue StandardError => e
        er_error_count += 1
        puts "ER (legacy) error on org #{org&.hbx_id}: #{e.message}" unless Rails.env.test?
      end

      CSV.open(file_name, 'w', force_quotes: true) do |csv|
        # --- EE Preference ---
        csv << ['EE Communication Preference', '']
        preferences.each { |p| csv << [p, ee_pref_counts[p]] }
        csv << ['Total', ee_total]
        csv << []

        # --- EE Language ---
        csv << ['EE Language Preference', '']
        languages.each { |l| csv << [l, ee_lang_counts[l]] }
        csv << ['Total', ee_total]
        csv << []

        # --- EE cross-tab ---
        csv << ['EE Preference and Language', *languages]
        preferences.each { |p| csv << [p, *languages.map { |l| ee_matrix[p][l] }] }
        csv << []

        # --- ER Preference (ERs have no language preference field) ---
        csv << ['ER Communication Preference', '']
        preferences.each { |p| csv << [p, er_pref_counts[p]] }
        csv << ['Total', er_total]
      end

      puts "Report written to: #{file_name}" unless Rails.env.test?
      puts "EE rows: #{ee_total} (errors: #{ee_error_count}), ER rows: #{er_total} (errors: #{er_error_count})" unless Rails.env.test?
    end
  end
end

# Returns the display bucket for an employer's active state, handling both
# legacy EmployerProfile (has_active_state?) and BenefitSponsors profiles
# (active_benefit_application).
def er_active_employer?(employer)
  if employer.respond_to?(:has_active_state?)
    employer.has_active_state?
  else
    employer.active_benefit_application.present?
  end
end

# Maps the raw contact_method to one of the three canonical preference buckets.
# Handles both:
#   - String values on EmployeeRole / legacy EmployerProfile
#     e.g. "Paper and Electronic communications", "Only Electronic communications"
#   - Symbol values on BenefitSponsors profiles
#     e.g. :paper_and_electronic, :paper_only, :electronic_only
def communication_preference_bucket(raw)
  contact = raw.to_s
  if contact.include?('paper_and_electronic') || contact.include?('Paper and Electronic')
    'Paper and Electronic'
  elsif contact.include?('electronic_only') || contact.include?('Electronic')
    'Electronic'
  elsif contact.include?('paper_only') || contact.include?('Paper')
    'Paper'
  else
    'Other or Blank'
  end
end

# Maps the raw language_preference string stored on EmployeeRole to one of
# the three canonical language buckets used in this report.
def language_preference_bucket(raw)
  case raw.to_s.strip.downcase
  when 'english', 'en'   then 'English'
  when 'spanish', 'es'   then 'Spanish'
  when 'amharic', 'am'   then 'Amharic'
  else                        'Other or Blank'
  end
end
