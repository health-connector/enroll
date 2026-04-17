# frozen_string_literal: true

# Generates a summary of communication preference and language preference
# elections for active SHOP employers (ERs) and active employees (EEs) only.
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

      pref_counts = Hash.new(0)
      lang_counts = Hash.new(0)
      matrix      = Hash.new { |h, k| h[k] = Hash.new(0) }
      total       = 0
      error_count = 0

      puts "Starting communication preference report at #{Time.now}"

      Person.all_employee_roles.active.no_timeout.each do |person|
        person.active_employee_roles.each do |er|
          begin
            employer = er.employer_profile
            next unless employer.present? && er_active_employer?(employer)

            pref = communication_preference_bucket(er.contact_method)
            lang = language_preference_bucket(er.language_preference)

            pref_counts[pref] += 1
            lang_counts[lang] += 1
            matrix[pref][lang] += 1
            total += 1
          rescue Exception => e
            error_count += 1
            puts "Error on employee_role #{er&.id} (person #{person&.hbx_id}): #{e.message}"
          end
        end
      end

      CSV.open(file_name, 'w', force_quotes: true) do |csv|
        csv << ['Preference', '']
        preferences.each { |p| csv << [p, pref_counts[p]] }
        csv << ['Total', total]
        csv << []
        csv << ['Language', '']
        languages.each { |l| csv << [l, lang_counts[l]] }
        csv << ['Total', total]
        csv << []
        csv << ['Preference and Language', *languages]
        preferences.each { |p| csv << [p, *languages.map { |l| matrix[p][l] }] }
      end

      puts "Report written to: #{file_name}"
      puts "Total active EE rows: #{total}, Errors skipped: #{error_count}"
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

# Maps the raw contact_method string stored on EmployeeRole to one of the
# three canonical preference buckets used in this report.
def communication_preference_bucket(raw)
  contact = raw.to_s
  if contact.include?('Paper and Electronic')
    'Paper and Electronic'
  elsif contact.include?('Electronic')
    'Electronic'
  elsif contact.include?('Paper')
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
