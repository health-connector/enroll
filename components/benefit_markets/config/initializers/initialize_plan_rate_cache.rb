unless Rails.env.test?
  Rails.application.config.to_prepare do
    ::BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
  end
end
