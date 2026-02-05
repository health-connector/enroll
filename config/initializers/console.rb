# frozen_string_literal: true

# Console Boot Optimizations
#
# The following are skipped when running `rails console` for faster startup:
#
# 1. AMQP subscriptions (config/application.rb)
#    - 17 RabbitMQ subscriptions skipped to avoid connection timeouts
#
# 2. Plan details cache (config/initializers/plan_details_cache.rb)
#    - Caches::PlanDetails.load_record_cache! skipped
#
# 3. Product rate cache (components/benefit_markets/config/initializers/initialize_plan_rate_cache.rb)
#    - BenefitMarkets::Products::ProductRateCache.initialize_rate_cache! skipped
#
# 4. Product factor cache (components/benefit_markets/config/initializers/initialize_rate_factor_cache.rb)
#    - BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache! skipped
#
# 5. MongoDB I18n backend (config/initializers/i18n_backend.rb)
#    - Uses file-based translations instead of MongoDB
#
# All caches support lazy loading - they will load automatically on first use.
#
# To manually pre-load caches in console:
#   Caches::PlanDetails.load_record_cache!
#   BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!
#   BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!

Rails.application.configure do
  console do
    puts ""
    puts "=" * 65
    puts "    • AMQP subscriptions"
    puts "    • Plan details cache"
    puts "    • Product rate/factor caches"
    puts "    • MongoDB I18n backend"
    puts ""
    puts "  Caches load automatically on first use, or manually run:"
    puts "    Caches::PlanDetails.load_record_cache!"
    puts "=" * 65
    puts ""
  end
end
