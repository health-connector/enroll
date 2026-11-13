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
      entries = load_payload
      updated_records = entries.map do |entry|
        update_endpoint(entry)
      end
      unconfigured_records = clear_unconfigured_endpoints(entries.map { |entry| entry['key'].to_s })
      verify_endpoints!(updated_records + unconfigured_records)
      updated_records
    end

    def self.abort_if_production!
      ::DataAnonymizer::Runner.abort_if_production!
    end

    private

    attr_reader :file_path, :dry_run

    def load_payload
      raise ArgumentError, "#{DEFAULT_FILE_ENV} is not set" if file_path.blank?

      entries = JSON.parse(File.read(file_path))
      case entries
      when Hash
        entries.map do |key, config|
          normalized_config(config).merge('key' => key)
        end
      when Array
        entries.map { |config| normalized_config(config) }
      else
        raise ArgumentError, 'endpoint override payload must be a hash or array'
      end
    rescue Errno::ENOENT
      raise ArgumentError, "override config not found at #{file_path}"
    rescue JSON::ParserError => e
      raise ArgumentError, "override config is not valid JSON: #{e.message}"
    end

    def normalized_config(config)
      hash = config.is_a?(Hash) ? config : {}
      {
        'key' => hash['key'] || hash[:key],
        'uri' => hash['uri'] || hash[:uri],
        'credentials' => normalize_credentials(hash['credentials'] || hash[:credentials])
      }
    end

    def normalize_credentials(raw_credentials)
      Array(raw_credentials).filter_map do |value|
        next if value.blank?

        credential = value.is_a?(Hash) ? value : JSON.parse(value.to_s)
        credential.transform_keys(&:to_s)
      rescue JSON::ParserError
        value
      end
    end

    def update_endpoint(entry)
      key = entry.fetch('key', nil).to_s
      raise ArgumentError, "override entry missing key" if key.blank?

      record = find_record(key)
      apply_uri(record, entry['uri'])
      if production_uri?(record.uri.to_s)
        record.credentials.clear
        persist_or_dry_run(record)
        log_result(record, 'cleared_credentials_for_production_uri')
        raise "endpoint #{record.key} still contains a production uri"
      end

      replace_credentials(record, entry['credentials'])
      verify_endpoint!(record)
      persist_or_dry_run(record)
      log_result(record, 'updated')
      record
    end

    def clear_unconfigured_endpoints(configured_keys)
      records = TransportProfiles::WellKnownEndpoint.all.to_a.reject do |record|
        configured_keys.include?(record.key.to_s)
      end
      records.each do |record|
        record.credentials.clear
        persist_or_dry_run(record)
        log_result(record, 'cleared_unconfigured_credentials')
      end
      records
    end

    def find_record(key)
      endpoint = TransportProfiles::WellKnownEndpoint.where(key: key).to_a
      raise "endpoint #{key} not found" if endpoint.empty?
      raise "endpoint #{key} is ambiguous" if endpoint.size > 1

      endpoint.first
    end

    def apply_uri(record, uri)
      record.uri = uri.to_s if uri.present?
    end

    def replace_credentials(record, desired_credentials)
      desired_credentials = Array(desired_credentials)
      keep_kinds = desired_credentials.map { |credential| credential['credential_kind'].to_s }.compact
      record.credentials = record.credentials.select do |credential|
        keep_kinds.include?(credential.credential_kind.to_s)
      end

      desired_credentials.each do |credential_data|
        sync_credential(record, credential_data)
      end
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

    def persist_or_dry_run(record)
      record.save! unless dry_run
    end

    def verify_endpoint!(record)
      raise "endpoint #{record.key} still contains a production uri" if production_uri?(record.uri.to_s)

      record.credentials.each do |credential|
        validate_credential(record.key, credential)
      end
    end

    def verify_endpoints!(records)
      records.each do |record|
        verify_endpoint!(record)
      end
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
