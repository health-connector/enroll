# frozen_string_literal: true

require_relative '../l10n_helper'

module Config::AcaHelper
  include ::L10nHelper

  def aca_state_abbreviation
    Settings.aca.state_abbreviation
  end

  def aca_state_name
    Settings.aca.state_name
  end

  def aca_primary_market
    Settings.aca.market_kinds.first
  end

  def allow_mid_month_voluntary_terms?
    Settings.aca.shop_market.mid_month_benefit_application_terminations.voluntary
  end

  def allow_mid_month_non_payment_terms?
    Settings.aca.shop_market.mid_month_benefit_application_terminations.non_payment
  end

  def add_deductible_display_enabled?
    EnrollRegistry[:add_deductible_display].feature.is_enabled
  end

  def aca_shop_market_employer_family_contribution_percent_minimum
    @aca_shop_market_employer_family_contribution_percent_minimum ||= Settings.aca.shop_market.employer_family_contribution_percent_minimum
  end

  def flexible_contribution_model_enabled_for_bqt_for_period
    application_period = ::EnrollRegistry[:flexible_contribution_model_for_bqt].setting(:initial_application_period).item.split('..')
    min = Date.strptime(application_period[0], '%m/%d/%Y')
    max = Date.strptime(application_period[1], '%m/%d/%Y')
    min..max
  end

  def retrive_date(val)
    val.split('-').first.size == 4 ? Date.strptime(val,"%Y-%m-%d") : Date.strptime(val,"%m/%d/%Y")
  end

  def hbx_shop_market_employer_family_contribution_percent_minimum
    @hbx_shop_market_employer_family_contribution_percent_minimum ||= Settings.aca.shop_market.amnesty.employer_family_contribution_percent_minimum
  end

  def flexible_family_contribution_percent_minimum_for_bqt
    @flexible_family_contribution_percent_minimum_for_bqt ||= ::EnrollRegistry[:flexible_contribution_model_for_bqt].setting(:employer_family_contribution_percent_minimum).item
  end

  def flexible_employer_contribution_percent_minimum_for_bqt
    @flexible_employer_contribution_percent_minimum_for_bqt ||= ::EnrollRegistry[:flexible_contribution_model_for_bqt].setting(:employer_contribution_percent_minimum).item
  end

  def family_contribution_percent_minimum_for_application_start_on(start_on, is_renewing)
    !is_renewing && flexible_contribution_model_enabled_for_bqt_for_period.cover?(start_on) ? flexible_family_contribution_percent_minimum_for_bqt : aca_shop_market_employer_family_contribution_percent_minimum
  end

  def employer_contribution_percent_minimum_for_application_start_on(start_on, is_renewing)
    !is_renewing && flexible_contribution_model_enabled_for_bqt_for_period.cover?(start_on) ? flexible_employer_contribution_percent_minimum_for_bqt : aca_shop_market_employer_contribution_percent_minimum
  end

  def flexbile_contribution_model_enabled_for_bqt_for_renewals
    @flexbile_contribution_model_enabled_for_bqt_for_renewals ||= ::EnrollRegistry[:flexible_contribution_model_for_bqt].setting(:enabled_for_renewal_applications).item
  end

  def shop_market_employer_family_contribution_percent_minimum
    amnesty_enabled_for_bqt? ? hbx_shop_market_employer_family_contribution_percent_minimum : aca_shop_market_employer_family_contribution_percent_minimum
  end

  def aca_shop_market_employer_contribution_percent_minimum
    @aca_shop_market_employer_contribution_percent_minimum ||= Settings.aca.shop_market.employer_contribution_percent_minimum
  end

  def aca_shop_market_valid_employer_attestation_documents_url
    @aca_shop_market_valid_employer_attestation_documents_url ||= Settings.aca.shop_market.valid_employer_attestation_documents_url
  end

  def aca_shop_market_new_employee_paper_application_is_enabled?
    @aca_shop_market_new_employee_paper_application ||= Settings.aca.shop_market.new_employee_paper_application
  end

  def aca_shop_market_census_employees_template_file
    @aca_shop_market_census_employees_template_file ||= Settings.aca.shop_market.census_employees_template_file
  end

  def aca_shop_market_coverage_start_period
    @aca_shop_market_coverage_start_period ||= Settings.aca.shop_market.coverage_start_period
  end

  # Allows us to conditionally display General Agency related links and information
  # This can be enabled or disabled in config/settings.yml
  # @return { True } if Settings.aca.general_agency_enabled
  # @return { False } otherwise
  def general_agency_enabled?
    Settings.aca.general_agency_enabled
  end

  def enrollments_reinstate_enabled?
    Settings.aca.enrollments_reinstate_enabled
  end

  def broker_carrier_appointments_enabled?
    Settings.aca.broker_carrier_appointments_enabled
  end

  def dental_market_enabled?
    Settings.aca.dental_market_enabled
  end

  def individual_market_is_enabled?
    @individual_market_is_enabled ||= Settings.aca.market_kinds.include?("individual")
  end

  def offer_sole_source?
    @offer_sole_source ||= Settings.aca.plan_options_available.include?("sole_source")
  end

  def enabled_sole_source_years
    @enabled_sole_source_years ||= Settings.aca.plan_option_years.sole_source_carriers_available
  end

  def offers_metal_level?
    @offer_metal_level ||= Settings.aca.plan_options_available.include?("metal_level")
  end

  def confirmation_action_title(confirmation_type)
    case confirmation_type.to_s
    when "reinstate"
      l10n("exchange.employer_applications.reinstated_on")
    when 'terminated', 'termination_pending'
      l10n("exchange.employer_applications.terminated_on")
    when 'canceled', 'retroactive_canceled'
      l10n("exchange.employer_applications.canceled_on")
    else
      l10n("exchange.employer_applications.action_taken_on")
    end
  end

  def confirmation_details_text(item)
    states = ["termination_pending", "terminated", "reinstate", "canceled", "retroactive_canceled"]
    text = item.state.to_s
    return text.titleize unless states.include?(text)

    confirmation_payload = {
      employer_id: item.benefit_application.benefit_sponsorship.id,
      employer_application_id: item.benefit_application.id,
      sequence_id: item.sequence_id
    }

    link_to(text.titleize, confirmation_details_exchanges_employer_applications_path(confirmation_payload))
  end

  def metal_levels_explained
    response = ""
    metal_level_contributions = {
      'bronze': '60%',
      'silver': '70%',
      'gold': '80%',
      'platinum': '90%'
    }.with_indifferent_access
    enabled_metal_levels_for_single_carrier.each_with_index do |level, index|
      if metal_level_contributions[level]
        if index == 0
          response << "#{level.capitalize} means the plan is expected to pay #{metal_level_contributions[level]} of expenses for an average population of consumers"
        elsif (index == enabled_metal_levels_for_single_carrier.length - 2) # subtracting 2 because of dental
          response << ", and #{level.capitalize} #{metal_level_contributions[level]}."
        else
          response << ", #{level.capitalize} #{metal_level_contributions[level]}"
        end
      end
    end
    response
  end

  # CCA requested a specific file format for MA
  #
  # @param task_name_DC [String] it will holds specific report task name for DC
  # @param task_name_MA[String] it will holds specific report task name for MA
  # EX: task_name_DC  "employers_list"
  #     task_name_MA "EMPLOYERSLIST"
  #
  # @return [String] absolute path location to writing a CSV
  def fetch_file_format(task_name_DC, task_name_MA)
    if individual_market_is_enabled?
      time_stamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")
      File.expand_path("#{Rails.root}/public/#{task_name_DC}_#{time_stamp}.csv")
    else
      # For MA stakeholders requested a specific file format
      time_extract = TimeKeeper.datetime_of_record.try(:strftime, '%Y_%m_%d_%H_%M_%S')
      File.expand_path("#{Rails.root}/public/CCA_#{ENV["RAILS_ENV"]}_#{task_name_MA}_#{time_extract}.csv")
    end
  end

  def enabled_metal_level_years
    @enabled_metal_level_years ||= Settings.aca.plan_option_years.metal_level_carriers_available
  end

  def offers_single_carrier?
    @offer_single_carrier ||= Settings.aca.plan_options_available.include?("single_carrier")
  end

  def enabled_single_carrier_years
    @enabled_single_carrier_years ||= Settings.aca.plan_option_years.single_carriers_available
  end

  def offers_single_plan?
    @offer_single_plan ||= Settings.aca.plan_options_available.include?("single_plan")
  end

  def offers_nationwide_plans?
    @offers_nationwide_plans ||= Settings.aca.nationwide_markets
  end

  def check_plan_options_title
    Settings.site.plan_options_title_for_ma
  end

  def enabled_metal_levels_for_single_carrier
    Settings.aca.enabled_metal_levels_for_single_carrier
  end

  def fetch_plan_title_for_sole_source
    Settings.plan_option_titles.sole_source
  end

  def fetch_plan_title_for_metal_level
    Settings.plan_option_titles.metal_level
  end

  def fetch_plan_title_for_single_carrier
    Settings.plan_option_titles.single_carrier
  end

  def fetch_plan_title_for_single_plan
    Settings.plan_option_titles.single_plan
  end

  def fetch_health_product_option_choice_description_for_sole_source
    Settings.plan_option_descriptions.sole_source
  end

  def fetch_health_product_option_choice_description_for_metal_level
    Settings.plan_option_descriptions.metal_level
  end

  def fetch_health_product_option_choice_description_for_single_carrier
    Settings.plan_option_descriptions.single_carrier
  end

  def fetch_health_product_option_choice_description_for_single_plan
    Settings.plan_option_descriptions.single_plan
  end

  def fetch_dental_product_option_choice_description_for_single_plan
    Settings.plan_option_descriptions.dental.single_plan
  end

  def fetch_invoices_addendum
    Settings.invoices.addendum
  end

  def carrier_special_plan_identifier_namespace
    @carrier_special_plan_identifier_namespace ||= Settings.aca.carrier_special_plan_identifier_namespace
  end

  def market_rating_areas
    @market_rating_areas ||= Settings.aca.rating_areas
  end

  def multiple_market_rating_areas?
    @multiple_market_rating_areas ||= Settings.aca.rating_areas.many?
  end

  def use_simple_employer_calculation_model?
    @use_simple_employer_calculation_model ||= (Settings.aca.use_simple_employer_calculation_model.to_s.downcase == "true")
  end

  def site_broker_quoting_enabled?
   Settings.site.broker_quoting_enabled
  end

  def site_broker_claim_quoting_enabled?
   Settings.site.broker_claim_quoting_enabled
  end

  def aca_address_query_county
    Settings.aca.address_query_county
  end

  def aca_broker_routing_information
    Settings.aca.broker_routing_information
  end

  def aca_security_questions
    Settings.aca.security_questions
  end

  def aca_user_accounts_enabled
    Settings.aca.user_accounts_enabled
  end

  def employer_attestation_is_enabled?
    Settings.aca.employer_attestation
  end

  def payment_pdf_helper
    if Settings.site.payment_pdf_url.match("http")
      Settings.site.payment_pdf_url
    else
      asset_path(Settings.site.payment_pdf_url)
    end
  end

  def display_plan_cost_warning(bg)
    return false unless offer_sole_source?
    return false if bg.nil?
    bg.sole_source?
  end

  def plan_match_tool_is_enabled?
    Settings.aca.plan_match_tool
  end

  def invoice_bill_url_helper
    Settings.site.invoice_bill_url
  end

  def payment_phone_number
    Settings.contact_center.payment_phone_number
  end

  def dental_offers_single_plan?
    Settings.aca.dental_plan_options_available.include?("single_plan")
  end

  def broker_agency_sent_messages_tab_enabled?
    Settings.aca.shop_market.broker_agency_profile.broker_agency_sent_messages_tab_enabled
  end
end
