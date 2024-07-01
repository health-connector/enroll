# frozen_string_literal: true

Before do
  Rails.cache.clear
  DatabaseCleaner.strategy = :deletion, {:except => %w[translations]}
  DatabaseCleaner.clean
end
