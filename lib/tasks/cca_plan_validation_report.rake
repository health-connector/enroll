# frozen_string_literal: true

# Generates the CCA plan-load validation reports, one workbook per carrier, after plans are loaded.
# RAILS_ENV=production bundle exec rake cca_plan_validation:reports active_date="2026-01-01" recipients="abc@example.gov"
# Optionally restrict to a single carrier:  issuer_hios_id="88806"
namespace :cca_plan_validation do

  def carrier_profiles(issuer_hios_id_filter = nil)
    profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten
    return profiles if issuer_hios_id_filter.blank?

    profiles.select do |profile|
      profile.issuer_hios_ids.any? { |id| id.to_s.start_with?(issuer_hios_id_filter) }
    end
  end

  def apply_issuer_scope(report, profile, hios_ids)
    report.define_singleton_method(:profiles) { [profile] }
    report.define_singleton_method(:products) do |year|
      BenefitMarkets::Products::Product.by_year(year).where(hios_id: /\A(#{hios_ids.join('|')})/)
    end
  end

  # Filesystem-safe, collision-free slug. `abbrev` is free text and not unique, so the
  # carrier's (product-backed) hios ids are appended to keep each carrier's file distinct.
  def carrier_slug(profile, hios_ids)
    [profile.abbrev.presence, *hios_ids].compact.join('_').gsub(/[^A-Za-z0-9]/, '_')
  end

  def build_carrier_report(active_date, profile)
    report = Services::PlanValidationReport.new(active_date)
    hios_ids = report.issuer_hios_ids_for(profile)
    return if hios_ids.empty?

    puts "Generating plan validation report for carrier: #{carrier_slug(profile, hios_ids)}" unless Rails.env.test?
    apply_issuer_scope(report, profile, hios_ids)

    report.sheet1
    report.sheet2
    report.sheet3
    report.sheet4
    report.sheet5
    report.sheet6
    report.sheet7
    report.sheet8
    report.sheet9

    current_date = Date.today.strftime("%Y_%m_%d")
    file_name = "#{Rails.root}/CCA_PlanLoadValidation_Report_#{carrier_slug(profile, hios_ids)}_#{current_date}.xlsx"
    report.generate_file(file_name)
    file_name
  end

  def run_validation_report(active_date, recipients, issuer_hios_id_filter = nil)
    generated_files = carrier_profiles(issuer_hios_id_filter).filter_map do |profile|
      build_carrier_report(active_date, profile)
    end

    if Rails.env.production?
      pubber = Publishers::Legacy::PlanValidationReportPublisher.new
      generated_files.each { |file_name| pubber.publish URI.join("file://", file_name) }
      UserMailer.generic_plan_validation_report_alert(recipients).deliver_now
    end

    generated_files
  end

  desc "reports generation after plan loading"
  task :reports => :environment do
    puts "Reports generation started" unless Rails.env.test?
    active_date = ENV['active_date'].to_date
    recipients = ENV.fetch('recipients', nil)
    issuer_hios_id_filter = ENV.fetch('issuer_hios_id', nil)
    run_validation_report(active_date, recipients, issuer_hios_id_filter)
  end
end
