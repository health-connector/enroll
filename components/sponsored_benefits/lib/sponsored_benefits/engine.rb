module SponsoredBenefits
  class Engine < ::Rails::Engine
    isolate_namespace SponsoredBenefits

    config.generators do |g|
      g.orm :mongoid
      g.template_engine :slim
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end


    initializer "sponsored_benefits.assets.precompile" do |app|
      app.config.assets.precompile += %w( plan_design_proposals.js pdf.scss )
    end
  end
end
