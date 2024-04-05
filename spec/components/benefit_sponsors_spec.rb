# frozen_string_literal: true

require 'rails_helper'

if begin
  "BenefitSponsors::Engine".constantize
   rescue StandardError
     puts "Error - #{e.message}"
    nil
end
#  Dir[Rails.root.join("components/benefit_markets/spec/factories/*.rb")].each do |f|
#    require f
#  end
#  Dir[Rails.root.join("components/benefit_sponsors/spec/factories/benefit_sponsors_*.rb")].each do |f|
#    require f
#  end
  Dir[Rails.root.join("components/benefit_sponsors/spec/**/*_spec.rb")].sort.each do |f|
    require f
  end
end
