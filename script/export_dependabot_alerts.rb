#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'csv'
require 'uri'
require 'optparse'

# Script to export Dependabot security alerts to CSV
class DependabotAlertsExporter
  GITHUB_API_URL = 'https://api.github.com'
  GRAPHQL_ENDPOINT = "#{GITHUB_API_URL}/graphql"

  def initialize(owner:, repo:, token:, output_file: 'dependabot_alerts.csv')
    @owner = owner
    @repo = repo
    @token = token
    @output_file = output_file
  end

  def export
    puts "Fetching Dependabot alerts for #{@owner}/#{@repo}..."
    alerts = fetch_dependabot_alerts
    
    if alerts.empty?
      puts "No alerts found."
      return
    end

    puts "Found #{alerts.length} alert(s). Exporting to CSV..."
    write_to_csv(alerts)
    puts "Successfully exported alerts to #{@output_file}"
  end

  private

  def fetch_dependabot_alerts
    # Using REST API v3 to fetch Dependabot alerts
    uri = URI("#{GITHUB_API_URL}/repos/#{@owner}/#{@repo}/dependabot/alerts")
    params = {
      state: 'open',
      severity: 'high,critical',
      per_page: 100
    }
    uri.query = URI.encode_www_form(params)

    alerts = []
    page = 1

    loop do
      uri.query = URI.encode_www_form(params.merge(page: page))
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Accept'] = 'application/vnd.github+json'
      request['X-GitHub-Api-Version'] = '2022-11-28'

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      case response.code.to_i
      when 200
        batch = JSON.parse(response.body)
        break if batch.empty?
        
        alerts.concat(batch)
        
        # Check if there are more pages
        link_header = response['Link']
        break unless link_header&.include?('rel="next"')
        
        page += 1
      when 401
        raise "Authentication failed. Please check your GitHub token."
      when 403
        raise "Access forbidden. Make sure your token has 'security_events' scope."
      when 404
        raise "Repository not found or Dependabot alerts are not enabled."
      else
        raise "API request failed with status #{response.code}: #{response.body}"
      end
    end

    alerts
  end

  def write_to_csv(alerts)
    CSV.open(@output_file, 'w') do |csv|
      # Write header
      csv << [
        'Number',
        'State',
        'Severity',
        'Package',
        'Ecosystem',
        'Vulnerable Version Range',
        'Fixed Version',
        'CVE ID',
        'GHSA ID',
        'Summary',
        'Description',
        'Created At',
        'Updated At',
        'Dismissed At',
        'Dismissed Reason',
        'Dismissed Comment',
        'URL'
      ]

      # Write data rows
      alerts.each do |alert|
        vulnerability = alert['security_vulnerability'] || {}
        package = vulnerability['package'] || {}
        advisory = alert['security_advisory'] || {}
        
        csv << [
          alert['number'],
          alert['state'],
          advisory['severity'],
          package['name'],
          package['ecosystem'],
          vulnerability['vulnerable_version_range'],
          vulnerability['first_patched_version']&.dig('identifier'),
          advisory['cve_id'],
          advisory['ghsa_id'],
          advisory['summary'],
          advisory['description']&.gsub(/\n/, ' ')&.strip,
          alert['created_at'],
          alert['updated_at'],
          alert['dismissed_at'],
          alert['dismissed_reason'],
          alert['dismissed_comment'],
          alert['html_url']
        ]
      end
    end
  end
end

# Command-line interface
if __FILE__ == $PROGRAM_NAME
  options = {
    owner: 'health-connector',
    repo: 'enroll',
    output_file: 'dependabot_alerts.csv'
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby export_dependabot_alerts.rb [options]"
    opts.separator ""
    opts.separator "This script exports Dependabot security alerts to a CSV file."
    opts.separator ""
    opts.separator "Options:"

    opts.on("-o", "--owner OWNER", "GitHub repository owner (default: health-connector)") do |owner|
      options[:owner] = owner
    end

    opts.on("-r", "--repo REPO", "GitHub repository name (default: enroll)") do |repo|
      options[:repo] = repo
    end

    opts.on("-t", "--token TOKEN", "GitHub personal access token (required)") do |token|
      options[:token] = token
    end

    opts.on("-f", "--file FILE", "Output CSV file (default: dependabot_alerts.csv)") do |file|
      options[:output_file] = file
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  # Check for required token
  unless options[:token]
    if ENV['GITHUB_TOKEN']
      options[:token] = ENV['GITHUB_TOKEN']
      puts "Using GITHUB_TOKEN from environment variable"
    else
      puts "Error: GitHub token is required."
      puts "Either provide it with -t/--token option or set GITHUB_TOKEN environment variable"
      puts ""
      puts "To create a token:"
      puts "1. Go to https://github.com/settings/tokens"
      puts "2. Generate a new token (classic)"
      puts "3. Select 'repo' and 'security_events' scopes"
      puts ""
      exit 1
    end
  end

  begin
    exporter = DependabotAlertsExporter.new(
      owner: options[:owner],
      repo: options[:repo],
      token: options[:token],
      output_file: options[:output_file]
    )
    exporter.export
  rescue StandardError => e
    puts "Error: #{e.message}"
    exit 1
  end
end
