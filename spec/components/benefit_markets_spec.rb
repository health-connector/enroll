# frozen_string_literal: true

require 'rails_helper'

if begin
  "BenefitMarkets::Engine".constantize
rescue StandardError
  nil
end
#  Dir[Rails.root.join("components/benefit_markets/spec/factories/*.rb")].each do |f|
#    require f
#  end
  Dir[Rails.root.join("components/benefit_markets/spec/**/*_spec.rb")].sort.each do |f|
    require f
  end
end
