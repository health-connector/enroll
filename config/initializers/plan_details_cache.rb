Rails.application.config.to_prepare do
  Caches::PlanDetails.load_record_cache!
end