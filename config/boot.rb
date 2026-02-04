# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# Monkey-patch for dry-auto_inject 0.6.1 compatibility with Ruby 3.2+ and Rails 7.2+
# The Builder class inherits from BasicObject and doesn't define is_a?/kind_of?
# which Zeitwerk calls during autoloading.
# This can be removed once dry-auto_inject is upgraded to 1.0+
require 'dry/auto_inject'
module Dry
  module AutoInject
    class Builder
      def is_a?(klass)
        ::Object.instance_method(:is_a?).bind(self).call(klass)
      end
      alias_method :kind_of?, :is_a?

      def instance_of?(klass)
        ::Object.instance_method(:instance_of?).bind(self).call(klass)
      end

      def class
        ::Object.instance_method(:class).bind(self).call
      end
    end
  end
end
