# frozen_string_literal: true

# Skip cache loading for console to speed up boot time
# Cache will be lazily loaded on first use
unless defined?(Rails::Console)
  Rails.application.config.to_prepare do
    Caches::PlanDetails.load_record_cache!
  end
end