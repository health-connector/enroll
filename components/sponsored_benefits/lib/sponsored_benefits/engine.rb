module SponsoredBenefits
  class Engine < ::Rails::Engine
    isolate_namespace SponsoredBenefits
    
    initializer "benefit_sponsors.factories", :after => "Factory_bot.set_factory_paths" do
      FactoryBot.definition_file_paths << File.expand_path('../../../spec/factories', __FILE__) if defined?(FactoryBot)
    end
    
    config.generators do |g|
      g.orm :mongoid
      g.template_engine :slim
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :Factory_bot, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end

    initializer :sponsored_benefits_assets do |app|
      # This is automatically done by Rails::Engine
      # app.config.assets.paths << root.join("app/assets/stylesheets")
      # so you can just require files without extra config
      #
      #   /* =require my_engine/application.css */

      # If you want to link directly:
      #
      #   <%= stylesheet_link_tag "sponsored_benefits/application.css" %>
      #
      # add that file to be precompiled
      # app.config.assets.precompile << "sponsored_benefits/application.css"
      #
      # or use manifest
      # ('app/assets/config' is automatically added to assets paths)
      app.config.assets.precompile << "sponsored_benefits_manifest.js"
    end
  end
end
