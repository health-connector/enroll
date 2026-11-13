# frozen_string_literal: true

require_relative '../data_anonymization/runner'

module TransportProfiles
  class EndpointOverride
    DEFAULT_FILE_ENV = 'TRANSPORT_ENDPOINT_OVERRIDE_FILE'
    DEFAULT_FILE_PATH = '/etc/secrets/transport_profiles_preprod_overrides.json'

    def initialize(file_path: nil, dry_run: false)
      @file_path = file_path || ENV.fetch(DEFAULT_FILE_ENV, DEFAULT_FILE_PATH)
      @dry_run = dry_run
    end

    def run
      self.class.abort_if_production!
      records = TransportProfiles::WellKnownEndpoint.all.to_a
      records = records.map(&:clone) if dry_run
      clear_credentials_before_override(records)
      entries = load_payload
      updated_records = entries.map do |entry|
        update_endpoint(entry, records)
      end
      configured_keys = updated_records.map { |record| record.key.to_s }
      verify_endpoints!(records, configured_keys)
      persist_updated_records(updated_records)
      verify_persisted_endpoints(records, configured_keys) unless dry_run
      updated_records
    end

    def self.abort_if_production!
      ::DataAnonymizer::Runner.abort_if_production!
    end

    private

    attr_reader :file_path, :dry_run

    def load_payload
      raise ArgumentError, "#{DEFAULT_FILE_ENV} is not set" if file_path.blank?

      parsed_payload = JSON.parse(File.read(file_path))
      entries = case parsed_payload
                when Hash
                  parsed_payload.map do |key, config|
                    normalized_config(config, key)
                  end
                when Array
                  parsed_payload.map { |config| normalized_config(config) }
                else
                  raise ArgumentError, 'endpoint override payload must be a hash or array'
                end
      raise ArgumentError, 'endpoint override payload must not be empty' if entries.empty?

      keys = entries.map { |entry| entry['key'] }
      raise ArgumentError, 'endpoint override payload contains duplicate keys' unless keys.uniq == keys

      entries
    rescue Errno::ENOENT
      raise ArgumentError, "override config not found at #{file_path}"
    rescue JSON::ParserError => e
      raise ArgumentError, "override config is not valid JSON: #{e.message}"
    end

    def normalized_config(config, default_key = nil)
      raise ArgumentError, 'endpoint override entry must be an object' unless config.is_a?(Hash)

      key = normalize_key(config, default_key)
      uri = normalize_uri(config, key)
      credentials = normalize_credentials(config['credentials'] || config[:credentials], key)
      validate_credentials_match_uri(key, uri, credentials)

      {
        'key' => key,
        'uri' => uri,
        'credentials' => credentials
      }
    end

    def normalize_key(config, default_key)
      key = (config['key'] || config[:key] || default_key).to_s
      raise ArgumentError, 'override entry missing key' if key.blank?
      raise ArgumentError, "override key does not match map key #{default_key}" if default_key.present? && key != default_key.to_s

      key
    end

    def normalize_uri(config, key)
      uri = config['uri'] || config[:uri]
      raise ArgumentError, "endpoint #{key} is missing a uri" unless uri.is_a?(String) && uri.present?
      raise ArgumentError, "endpoint #{key} still contains a production uri" if production_uri?(uri)

      uri
    end

    def validate_credentials_match_uri(key, uri, credentials)
      expected_kind = credential_kind_for_uri(uri, key)
      return if credentials.all? { |credential| credential['credential_kind'] == expected_kind }

      raise ArgumentError, "endpoint #{key} credential kind does not match its uri scheme"
    end

    def normalize_credentials(raw_credentials, key)
      raise ArgumentError, "endpoint #{key} must have at least one credential" unless raw_credentials.is_a?(Array) && raw_credentials.any?

      credentials = raw_credentials.map do |value|
        credential = parse_credential(value, key)
        kind = credential['credential_kind'].to_s
        raise ArgumentError, "endpoint #{key} has an unsupported credential kind" unless %w[sftp s3].include?(kind)

        credential.merge('credential_kind' => kind)
      end

      kinds = credentials.map { |credential| credential['credential_kind'] }
      raise ArgumentError, "endpoint #{key} has duplicate credential kinds" unless kinds.uniq == kinds

      credentials
    end

    def parse_credential(value, key)
      credential = if value.is_a?(Hash)
                     value
                   elsif value.is_a?(String)
                     JSON.parse(value)
                   end
      raise ArgumentError, "credential for endpoint #{key} must be an object" unless credential.is_a?(Hash)

      credential.transform_keys(&:to_s)
    rescue JSON::ParserError
      raise ArgumentError, "credential for endpoint #{key} is not valid JSON"
    end

    def clear_credentials_before_override(records)
      records.each { |record| record.credentials.clear }
      return if dry_run || records.empty?

      result = TransportProfiles::WellKnownEndpoint.collection.update_many(
        { '_id' => { '$in' => records.map(&:id) } },
        { '$set' => { 'credentials' => [] } }
      )
      raise 'failed to clear credentials from every transport endpoint' unless result.matched_count == records.size

      action = dry_run ? 'would_clear_before_override' : 'cleared_before_override'
      records.each { |record| log_result(record, action) }
    end

    def update_endpoint(entry, records)
      key = entry['key']
      endpoint = records.select { |record| record.key.to_s == key }
      raise "endpoint #{key} not found" if endpoint.empty?
      raise "endpoint #{key} is ambiguous" if endpoint.size > 1

      record = endpoint.first
      record.uri = entry['uri']
      record.credentials.clear
      entry['credentials'].each { |credential_data| sync_credential(record, credential_data) }
      record
    end

    def sync_credential(record, credential_data)
      kind = credential_data['credential_kind'].to_s
      return if kind.blank?

      credential = record.credentials.find { |existing| existing.credential_kind.to_s == kind }
      credential ||= record.credentials.build(credential_kind: kind)

      credential.account_name = credential_data['account_name']
      credential.access_key_id = credential_data['access_key_id']
      credential.encrypted_pass_phrase = nil
      credential.encrypted_private_rsa_key = nil
      credential.encrypted_secret_access_key = nil
      credential.pass_phrase = credential_data['pass_phrase'] if credential_data['pass_phrase'].present?
      credential.private_rsa_key = credential_data['private_rsa_key'] if credential_data['private_rsa_key'].present?
      credential.secret_access_key = credential_data['secret_access_key'] if credential_data['secret_access_key'].present?
    end

    def persist_updated_records(records)
      records.each do |record|
        record.save! unless dry_run
        log_result(record, 'updated')
      end
    end

    def verify_endpoint!(record, configured:)
      raise "endpoint #{record.key} still contains a production uri" if production_uri?(record.uri.to_s)

      expected_kind = credential_kind_for_uri(record.uri.to_s, record.key) if configured
      raise "endpoint #{record.key} is missing its #{expected_kind} credential" if configured && record.credentials.none? { |credential| credential.credential_kind == expected_kind }

      record.credentials.each do |credential|
        validate_credential(record.key, credential)
      end
    end

    def verify_endpoints!(records, configured_keys)
      records.each do |record|
        verify_endpoint!(record, configured: configured_keys.include?(record.key.to_s))
      end
    end

    def verify_persisted_endpoints(records, configured_keys)
      records.each(&:reload)
      verify_endpoints!(records, configured_keys)
    end

    def credential_kind_for_uri(uri, key)
      scheme = URI.parse(uri).scheme
      return scheme if %w[sftp s3].include?(scheme)

      raise ArgumentError, "endpoint #{key} has an unsupported uri scheme"
    rescue URI::InvalidURIError
      raise ArgumentError, "endpoint #{key} has an invalid uri"
    end

    def production_uri?(uri)
      production_pattern = /(?:(?<![a-z])mhc-prod-|(?<![a-z])prod[.-]|(?<![a-z])prod\z)/i
      uri.match?(production_pattern)
    end

    def validate_credential(key, credential)
      return if credential.credential_kind.blank?

      validate_sftp_credential(key, credential) if credential.sftp?
      validate_s3_credential(key, credential) if credential.s3?
    end

    def validate_sftp_credential(key, credential)
      raise "endpoint #{key} has blank sftp account" if credential.account_name.blank?
      raise "endpoint #{key} has blank sftp password" if credential.pass_phrase.blank? && credential.private_rsa_key.blank?
    end

    def validate_s3_credential(key, credential)
      raise "endpoint #{key} has blank s3 access key" if credential.access_key_id.blank?
      raise "endpoint #{key} has blank s3 secret key" if credential.secret_access_key.blank?
    end

    def log_result(record, action)
      Rails.logger.tagged(self.class.name) do
        Rails.logger.info("transport endpoint key=#{record.key} scheme=#{uri_scheme(record.uri)} action=#{action} dry_run=#{dry_run}")
      end
    end

    def uri_scheme(uri)
      return 'unknown' if uri.blank?

      URI.parse(uri).scheme.to_s
    rescue URI::InvalidURIError
      'unknown'
    end
  end
end
