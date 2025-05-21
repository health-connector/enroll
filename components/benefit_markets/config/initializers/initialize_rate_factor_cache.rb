unless Rails.env.test?
  Rails.application.config.to_prepare do
    BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
  end
end
