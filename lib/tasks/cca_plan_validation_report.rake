# frozen_string_literal: true

# Generates the CCA plan-load validation reports after plans are loaded: one combined workbook for all
# carriers plus one workbook per carrier, written to a dated CCA_PlanLoadValidation_<date>/ folder.
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

  def apply_issuer_scope(report, profiles, hios_ids)
    report.define_singleton_method(:profiles) { profiles }
    report.define_singleton_method(:products) do |year|
      BenefitMarkets::Products::Product.by_year(year).where(hios_id: /\A(#{hios_ids.join('|')})/)
    end
  end

  # Filesystem-safe, collision-free slug. `abbrev` is free text and not unique, so the
  # carrier's (product-backed) hios ids are appended to keep each carrier's file distinct.
  def carrier_slug(profile, hios_ids)
    [profile.abbrev.presence, *hios_ids].compact.join('_').gsub(/[^A-Za-z0-9]/, '_')
  end

  # All output lands in one dated folder: the combined workbook at its root and one
  # workbook per carrier under per_carrier/.
  def report_output_dir
    File.join(Rails.root.to_s, "CCA_PlanLoadValidation_#{Date.today.strftime('%Y_%m_%d')}")
  end

  def write_report(active_date, profiles, hios_ids, file_name)
    report = Services::PlanValidationReport.new(active_date)
    apply_issuer_scope(report, profiles, hios_ids)

    report.sheet1
    report.sheet2
    report.sheet3
    report.sheet4
    report.sheet5
    report.sheet6
    report.sheet7
    report.sheet8
    report.sheet9

    FileUtils.mkdir_p(File.dirname(file_name))
    report.generate_file(file_name)
    file_name
  end

  def build_carrier_report(active_date, profile)
    hios_ids = Services::PlanValidationReport.new(active_date).issuer_hios_ids_for(profile)
    return if hios_ids.empty?

    slug = carrier_slug(profile, hios_ids)
    puts "Generating plan validation report for carrier: #{slug}" unless Rails.env.test?
    file_name = File.join(report_output_dir, 'per_carrier', "CCA_PlanLoadValidation_Report_#{slug}_#{Date.today.strftime('%Y_%m_%d')}.xlsx")
    write_report(active_date, [profile], hios_ids, file_name)
  end

  def build_combined_report(active_date, profiles)
    lookup = Services::PlanValidationReport.new(active_date)
    hios_ids = profiles.flat_map { |profile| lookup.issuer_hios_ids_for(profile) }
    return if hios_ids.empty?

    puts "Generating combined plan validation report for all carriers" unless Rails.env.test?
    file_name = File.join(report_output_dir, "CCA_PlanLoadValidation_Report_ALL_#{Date.today.strftime('%Y_%m_%d')}.xlsx")
    write_report(active_date, profiles, hios_ids, file_name)
  end

  def run_validation_report(active_date, recipients, issuer_hios_id_filter = nil)
    profiles = carrier_profiles(issuer_hios_id_filter)
    generated_files = [build_combined_report(active_date, profiles)]
    generated_files += profiles.map { |profile| build_carrier_report(active_date, profile) }
    generated_files.compact!

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
