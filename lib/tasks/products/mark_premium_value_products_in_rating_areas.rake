# frozen_string_literal: true

require File.join(Rails.root, "app", "data_migrations", "products", "mark_premium_value_products_in_rating_areas")
# This rake task is to mark premium value products in given rating areas
# RAILS_ENV=production bundle exec rake migrations:mark_premium_value_products_in_rating_areas file_name="test.csv"

namespace :migrations do
  desc "mark premium value products in given rating areas"
  MarkPremiumValueProductsInRatingAreas.define_task :mark_premium_value_products_in_rating_areas => :environment
end