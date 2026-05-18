module TransportProfiles
  class Engine < ::Rails::Engine
    isolate_namespace TransportProfiles

    config.generators do |g|
      g.orm :mongoid
      g.test_framework :rspec, :fixture => false
      g.assets false
      g.helper false
    end

    initializer :transport_profiles_assets do |app|
      app.config.assets.precompile << "transport_profiles_manifest.js"
    end
  end
end
