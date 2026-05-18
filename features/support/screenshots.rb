# frozen_string_literal: true

Before do |scenario|
  @count = 0

  # Get scenario name
  @scenario_name = scenario.name.downcase.gsub(' ', '_')

  # Get feature name (it's in file path)
  location = scenario.location.to_s
  file_path = location.split(':').first
  file_name = File.basename(file_path, '.feature')
  @feature_name = file_name.downcase.gsub(' ', '_')
end

module Screenshots
  def screenshot(name, options = {})
    page.save_screenshot "tmp/#{@feature_name}/#{@scenario_name}/#{@count += 1} - #{name}.png", full: true if (ENV['SCREENSHOTS'] == 'true') || options[:force]
  end
end

World(Screenshots)
