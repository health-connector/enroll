# require 'ckeditor'

require 'mongoid'
require 'virtus'
require "aasm"
require "wkhtmltopdf-binary-edge"
require "wicked_pdf"
require 'ckeditor'
require "config"
require "money-rails"
require 'pundit'

module Notifier
  class Engine < ::Rails::Engine
    isolate_namespace Notifier

    config.generators do |g|
      g.orm :mongoid
      g.template_engine :slim
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :Factory_bot, :dir => 'spec/factories'
      g.assets true
      g.helper true
    end

    initializer :notifier_assets do |app|
      app.config.assets.precompile << "notifier_manifest.js"
    end
  end
end
