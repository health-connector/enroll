# frozen_string_literal: true

require 'rails_helper'

if begin
  "TransportProfiles::Engine".constantize
   rescue StandardError
     puts "Error - #{e.message}"
  nil
end
  Dir[Rails.root.join("components/transport_profiles/spec/**/*_spec.rb")].sort.each do |f|
    require f
  end
end
