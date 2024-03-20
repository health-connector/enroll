# frozen_string_literal: true

require 'rails_helper'

if begin
  "Notifier::Engine".constantize
rescue StandardError
  nil
end
  Dir[Rails.root.join("components/notifier/spec/**/*_spec.rb")].sort.each do |f|
    require f
  end
end
