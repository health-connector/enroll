# frozen_string_literal: true

require 'csv'

namespace :migrations do
  # Counts the "Referred by: How did you find out about the Massachusetts Health Connector?"
  # answers of active MA SHOP employers. An employer is counted once if it has a benefit
  # application with coverage (active, termination pending, terminated or expired) whose
  # effective period overlaps the requested dates.
  #
  # Dates are MM/DD/YYYY. Pass a single date to report on employers active on that day,
  # or a start and end date to report on a range (for example a quarter).
  #
  # RAILS_ENV=production bundle exec rake migrations:employer_referral_source_report['07/01/2026','09/30/2026']
  # RAILS_ENV=production bundle exec rake migrations:employer_referral_source_report['09/30/2026']
  desc "Report of referral source counts for active SHOP employers within a date range"
  task :employer_referral_source_report, [:start_date, :end_date] => :environment do |_task, args|
    include Config::AcaHelper

    parse_date = lambda do |value|
      Date.strptime(value.to_s.strip, "%m/%d/%Y")
    rescue ArgumentError
      abort "Invalid date '#{value}'. Use MM/DD/YYYY, for example: rake migrations:employer_referral_source_report['07/01/2026','09/30/2026']"
    end

    abort "Please provide a start date (MM/DD/YYYY) and optionally an end date." if args[:start_date].blank?

    start_date = parse_date.call(args[:start_date])
    end_date = args[:end_date].present? ? parse_date.call(args[:end_date]) : start_date
    abort "End date #{end_date} cannot be before start date #{start_date}." if end_date < start_date

    coverage_states = BenefitSponsors::BenefitApplications::BenefitApplication::COVERAGE_EFFECTIVE_STATES + [:terminated, :expired]

    covers_dates = lambda do |application|
      application_start = application.start_on
      application_end = application.end_on
      next false if application_start.blank? || application_end.blank?

      application_start.to_date <= end_date && application_end.to_date >= start_date
    end

    sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
      :benefit_applications.elem_match => { :aasm_state.in => coverage_states }
    )

    referral_counts = Hash.new(0)
    employer_count = 0

    sponsorships.each do |sponsorship|
      next unless sponsorship.benefit_applications.any? { |application| coverage_states.include?(application.aasm_state) && covers_dates.call(application) }

      profile = sponsorship.profile
      next unless profile.respond_to?(:referred_by)

      referral_counts[profile.referred_by.presence || "(Not Specified / Blank)"] += 1
      employer_count += 1
    end

    known_kinds = BenefitSponsors::Organizations::AcaShopCcaEmployerProfile::REFERRED_KINDS
    extra_sources = referral_counts.keys - known_kinds
    rows = (known_kinds + extra_sources).map do |source|
      count = referral_counts[source]
      percent = employer_count.positive? ? (count.to_f / employer_count * 100).round(1) : 0.0
      [source, count, percent]
    end

    period = start_date == end_date ? start_date.to_s : "#{start_date} - #{end_date}"
    file_name = fetch_file_format('employer_referral_source_report', 'EMPLOYERREFERRALSOURCEREPORT')

    CSV.open(file_name, "w") do |csv|
      csv << ["Referral Source", "Count", "Percent"]
      rows.each { |source, count, percent| csv << [source.strip, count, percent] }
      csv << ["TOTAL", employer_count, 100.0]
    end

    puts "=" * 80
    puts "REFERRAL SOURCE REPORT - Active MA SHOP Employers"
    puts "Period: #{period}"
    puts "=" * 80
    print_row = lambda do |source, count, percent|
      puts "#{source.strip.truncate(62).ljust(62)}  #{count.to_s.rjust(5)}  #{percent.to_s.rjust(5)}%"
    end

    puts "#{'Referral Source'.ljust(62)}  #{'Count'.rjust(5)}  #{'Pct'.rjust(6)}"
    puts "-" * 80
    rows.each { |source, count, percent| print_row.call(source, count, percent) }
    puts "-" * 80
    print_row.call("TOTAL", employer_count, 100.0)
    puts "=" * 80
    puts "Report written to #{file_name}"
  end
end
