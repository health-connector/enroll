# frozen_string_literal: true

Rails.application.config.after_initialize do
  Caches::PlanDetails.load_record_cache!
end