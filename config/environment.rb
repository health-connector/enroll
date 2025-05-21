# frozen_string_literal: true

require 'yaml' # Added to the top to patch YAML before Rails loads

# Patch YAML to always allow aliases - this issue gets fixed in Rails 7
# Remove the `module YAML` block when upgrading to Rails 7
module YAML
  class << self
    alias original_load load # Retain original load method

    # Create custom load method
    def load(yaml, *, **keywords)
      # Enable aliases if not explicitly disabled
      # without this, aliases are disabled by default, and any .yml file using `*default` will fail to load
      keywords[:aliases] = true unless keywords.key?(:aliases)

      # Call original method with modified keyword params
      original_load(yaml, *, **keywords)
    end
  end
end

# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!
