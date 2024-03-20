# frozen_string_literal: true

require 'rails_helper'

if begin
  "SponsoredBenefits::Engine".constantize
rescue StandardError
  nil
end
  # Dir[Rails.root.join("components/sponsored_benefits/spec/factories/sponsored_benefits_*.rb")].each do |f|
  #   require f
  # end
  Dir[Rails.root.join("components/sponsored_benefits/spec/**/*_spec.rb")].sort.each do |f|
    require f
  end
end
