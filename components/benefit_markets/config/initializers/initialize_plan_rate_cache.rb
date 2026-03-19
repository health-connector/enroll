unless Rails.env.test?
  Rails.application.config.after_initialize do
    BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
  end
end
