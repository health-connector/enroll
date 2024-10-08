# frozen_string_literal: true

Before do |scenario|
  @count = 0
  case scenario
  when Cucumber::RunningTestCase::ScenarioOutlineExample
    @scenario_name = scenario.scenario_outline.name.downcase.gsub(' ', '_')
    @feature_name = scenario.scenario_outline.feature.name.downcase.gsub(' ', '_')
  when Cucumber::RunningTestCase::Scenario
    @scenario_name = scenario.name.downcase.gsub(' ', '_')
    @feature_name = scenario.feature.name.downcase.gsub(' ', '_')
  else
    raise("Unhandled class, look in features/support/screenshots.rb")
  end
end

module Screenshots
  def screenshot(name, options = {})
    page.save_screenshot "tmp/#{@feature_name}/#{@scenario_name}/#{@count += 1} - #{name}.png", full: true if (ENV['SCREENSHOTS'] == 'true') || options[:force]
  end
end

World(Screenshots)
