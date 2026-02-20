# frozen_string_literal: true

# Skip cache loading for console to speed up boot time
# Cache will be lazily loaded on first use
if !Rails.env.test? && !defined?(Rails::Console)
  Rails.application.config.to_prepare do
    BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!
  end
end
