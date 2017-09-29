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

  def aca_shop_market_employer_contribution_percent_minimum
    @aca_shop_market_employer_contribution_percent_minimum ||= Settings.aca.shop_market.employer_contribution_percent_minimum
  end

  def aca_shop_market_valid_employer_attestation_documents_url
    @aca_shop_market_valid_employer_attestation_documents_url ||= Settings.aca.shop_market.valid_employer_attestation_documents_url
  end


  # Allows us to conditionally display General Agency related links and information
  # This can be enabled or disabled in config/settings.yml
  # @return { True } if Settings.aca.general_agency_enabled
  # @return { False } otherwise
  def general_agency_enabled?
    Settings.aca.general_agency_enabled
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

  def offers_metal_level?
    @offer_metal_level ||= Settings.aca.plan_options_available.include?("metal_level")
  end

  def offers_single_carrier?
    @offer_single_carrier ||= Settings.aca.plan_options_available.include?("single_carrier")
  end

  def offers_single_plan?
    @offer_single_plan ||= Settings.aca.plan_options_available.include?("single_plan")
  end

  def offers_nationwide_plans?
    @offers_nationwide_plans ||= Settings.aca.nationwide_markets
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

  def site_broker_enabled?
   Settings.site.broker_enabled
  end

end
