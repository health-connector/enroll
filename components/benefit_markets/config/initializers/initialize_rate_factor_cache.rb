unless Rails.env.test?
  Rails.application.config.after_initialize do
    BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
  end
end
