module Config::BrokerAgencyHelper
  def site_broker_quoting_enabled?
   Settings.site.broker_quoting_enabled
  end

end
