# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')


# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w( notifier/ckeditor/* )
Rails.application.config.assets.precompile += %w[glossary.js]
Rails.application.config.assets.paths << Rails.root.join('components', 'sponsored_benefits', 'app', 'assets')

if Gem.loaded_specs.key?('chosen-rails')
  chosen_root = Gem.loaded_specs['chosen-rails'].full_gem_path
  Rails.application.config.assets.paths << File.join(chosen_root, 'vendor', 'assets', 'javascripts')
  Rails.application.config.assets.paths << File.join(chosen_root, 'vendor', 'assets', 'stylesheets')
end