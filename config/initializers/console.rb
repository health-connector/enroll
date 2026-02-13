# frozen_string_literal: true

Rails.application.configure do
  console do
    puts ""
    puts "=" * 70
    puts "  All caches support lazy loading - they load automatically on first use."
    puts ""
    puts "  To manually pre-load caches in console:"
    puts "    Caches::PlanDetails.load_record_cache!"
    puts "    BenefitMarkets::Products::ProductRateCache.initialize_rate_cache!"
    puts "    BenefitMarkets::Products::ProductFactorCache.initialize_factor_cache!"
    puts "=" * 70
    puts ""
  end
end
