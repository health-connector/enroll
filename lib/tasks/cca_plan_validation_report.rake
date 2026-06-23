# frozen_string_literal: true

# This rake tasks should be run to generate reports after plans loading.
# To generate all reports please use this rake command: RAILS_ENV=production bundle exec rake cca_plan_validation:reports active_date="2019-12-01" recipients="abc@example.gov,aba1@example.com"
namespace :cca_plan_validation do

  def apply_issuer_hios_scope(report, issuer_hios_id_filter)
    report.define_singleton_method(:profiles) do
      BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles
        .select { |eo| eo.issuer_profile.issuer_hios_ids.any? { |id| id.to_s.start_with?(issuer_hios_id_filter) } }
        .map(&:profiles).flatten
    end

    report.define_singleton_method(:products) do |year|
      ::BenefitMarkets::Products::Product.by_year(year).where(hios_id: /\A#{issuer_hios_id_filter}/)
    end
  end

  def run_validation_report(active_date, recipients, issuer_hios_id_filter)
    report = Services::PlanValidationReport.new(active_date)
    apply_issuer_hios_scope(report, issuer_hios_id_filter)

    puts "Filtering report to issuer_hios_id: #{issuer_hios_id_filter} for active_date: #{active_date}" unless Rails.env.test?

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
    file_name = "#{Rails.root}/CCA_PlanLoadValidation_Report_EA_#{current_date}.xlsx"
    report.generate_file(file_name)

    if Rails.env.production?
      pubber = Publishers::Legacy::PlanValidationReportPublisher.new
      pubber.publish URI.join("file://", file_name)
      UserMailer.generic_plan_validation_report_alert(recipients).deliver_now
    end

    file_name
  end

  desc "reports generation after plan loading"
  task :reports => :environment do
    puts "Reports generation started" unless Rails.env.test?
    active_date = ENV['active_date'].to_date
    recipients = ENV['recipients']
    issuer_hios_id_filter = ENV['issuer_hios_id'] || '88806'
    run_validation_report(active_date, recipients, issuer_hios_id_filter)
  end
end
