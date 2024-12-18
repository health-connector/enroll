module Config::AcaHelper
  def aca_state_abbreviation
    Settings.aca.state_abbreviation
  end

  def aca_state_name
    Settings.aca.state_name
  end

  def aca_primary_market
    Settings.aca.market_kinds.first
  end

  def aca_shop_market_employer_family_contribution_percent_minimum
    @aca_shop_market_employer_family_contribution_percent_minimum ||= Settings.aca.shop_market.employer_family_contribution_percent_minimum
  end

  def flexible_contribution_model_enabled_for_bqt_for_period
    ::EnrollRegistry[:flexible_contribution_model_for_bqt].setting(:initial_application_period).item
  end

  def retrive_date(val)
    val.split('-').first.size == 4 ? Date.strptime(val,"%Y-%m-%d") : Date.strptime(val,"%m/%d/%Y")
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

  def aca_shop_market_employer_contribution_percent_minimum
    @aca_shop_market_employer_contribution_percent_minimum ||= Settings.aca.shop_market.employer_contribution_percent_minimum
  end

  def aca_shop_market_employer_dental_contribution_percent_minimum
    @aca_shop_market_employer_dental_contribution_percent_minimum ||= Settings.aca.shop_market.employer_dental_contribution_percent_minimum
  end

  def aca_shop_market_valid_employer_attestation_documents_url
    @aca_shop_market_valid_employer_attestation_documents_url ||= Settings.aca.shop_market.valid_employer_attestation_documents_url
  end

  def aca_shop_market_new_employee_paper_application_is_enabled?
    @aca_shop_market_new_employee_paper_application_is_enabled ||= Settings.aca.shop_market.new_employee_paper_application
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
    @offers_metal_level ||= Settings.aca.plan_options_available.include?("metal_level")
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
      next unless metal_level_contributions[level]
      return "#{level.capitalize} means the plan is expected to pay #{metal_level_contributions[level]} of expenses for an average population of consumers" if index == 0
      return ", and #{level.capitalize} #{metal_level_contributions[level]}." if index == enabled_metal_levels_for_single_carrier.length - 2 # subtracting 2 because of dental

      response << ", #{level.capitalize} #{metal_level_contributions[level]}"
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
  def fetch_file_format(task_name_dc, task_name_ma)
    if individual_market_is_enabled?
      time_stamp = Time.now.utc.strftime("%Y%m%d_%H%M%S")
      File.expand_path("#{Rails.root}/public/#{task_name_dc}_#{time_stamp}.csv")
    else
      # For MA stakeholders requested a specific file format
      time_extract = TimeKeeper.datetime_of_record.try(:strftime, '%Y_%m_%d_%H_%M_%S')
      File.expand_path("#{Rails.root}/public/CCA_#{ENV['RAILS_ENV']}_#{task_name_ma}_#{time_extract}.csv")
    end
  end

  def enabled_metal_level_years
    @enabled_metal_level_years ||= Settings.aca.plan_option_years.metal_level_carriers_available
  end

  def offers_single_carrier?
    @offers_single_carrier ||= Settings.aca.plan_options_available.include?("single_carrier")
  end

  def enabled_single_carrier_years
    @enabled_single_carrier_years ||= Settings.aca.plan_option_years.single_carriers_available
  end

  def offers_single_plan?
    @offers_single_plan ||= Settings.aca.plan_options_available.include?("single_plan")
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

  def multiple_market_rating_areas?
    @multiple_market_rating_areas ||= Settings.aca.rating_areas.many?
  end
end