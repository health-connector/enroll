module TransportGateway
  class Engine < ::Rails::Engine
    isolate_namespace TransportGateway

    config.generators do |g|
      g.test_framework :rspec, :fixture => false
      g.assets false
      g.helper false
    end

    initializer :transport_gateway_assets do |app|
      app.config.assets.precompile << "transport_gateway_manifest.js"
    end
  end
end
