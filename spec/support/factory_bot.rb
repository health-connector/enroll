# frozen_string_literal: true

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Acheived by adding Initializer in engine
  # FactoryBot.definition_file_paths = [
  #   File.expand_path('../../../components/benefit_markets/spec/factories', __FILE__),
  #   File.expand_path('../../../components/benefit_sponsors/spec/factories', __FILE__),
  # ]
  # FactoryBot.find_definitions

  config.before(:suite) do

    DatabaseCleaner.start
    # FactoryBot.lint
  ensure
    DatabaseCleaner.clean

  end

end
