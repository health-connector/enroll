# frozen_string_literal: true

Rails.application.config.to_prepare do
  Caches::PlanDetails.load_record_cache!
end