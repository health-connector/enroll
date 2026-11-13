# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransportProfiles::EndpointOverride, type: :model do
  around do |example|
    original_env_name = ENV.fetch('ENV_NAME', nil)
    original_review_env = ENV.fetch('ENROLL_REVIEW_ENVIRONMENT', nil)
    ENV['ENV_NAME'] = 'preprod'
    ENV['ENROLL_REVIEW_ENVIRONMENT'] = 'true'
    example.run
  ensure
    ENV['ENV_NAME'] = original_env_name
    ENV['ENROLL_REVIEW_ENVIRONMENT'] = original_review_env
  end

  let(:temp_file) { Tempfile.new(['endpoint_override', '.json']) }
  let(:payload) do
    {
      'aca_shop_analytics_outbound' => {
        'uri' => 'sftp://preprod-sftp.example.com/data',
        'credentials' => [
          {
            'credential_kind' => 'sftp',
            'account_name' => 'preprod_sftp_user',
            'pass_phrase' => 'new-preprod-password'
          }
        ]
      }
    }
  end

  before do
    TransportProfiles::WellKnownEndpoint.delete_all
    temp_file.write(payload.to_json)
    temp_file.rewind
  end

  after do
    temp_file.close
    temp_file.unlink
    TransportProfiles::WellKnownEndpoint.delete_all
  end

  describe '#run' do
    it 'updates the matching endpoint uri and embedded credential values' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password',
            private_rsa_key: 'prod-private-key'
          )
        ]
      )

      described_class.new(file_path: temp_file.path).run

      endpoint.reload
      expect(endpoint.uri).to eq('sftp://preprod-sftp.example.com/data')
      expect(endpoint.credentials.first.account_name).to eq('preprod_sftp_user')
      expect(endpoint.credentials.first.pass_phrase).to eq('new-preprod-password')
      expect(endpoint.credentials.first.private_rsa_key).to be_nil
    end

    it 'does not write when dry_run is enabled' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )
      unconfigured_endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'legacy data extracts',
        site_key: 'mhc',
        key: 'aca_legacy_data_extracts',
        market_kind: 'any',
        uri: 'sftp://preprod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'preprod_sftp_user',
            pass_phrase: 'preprod-password'
          )
        ]
      )

      described_class.new(file_path: temp_file.path, dry_run: true).run

      endpoint.reload
      unconfigured_endpoint.reload
      expect(endpoint.uri).to eq('sftp://prod-sftp.example.com/data')
      expect(endpoint.credentials.first.pass_phrase).to eq('prod-password')
      expect(unconfigured_endpoint.credentials.first.pass_phrase).to eq('preprod-password')
    end

    it 'clears credentials from endpoints missing a preprod override and fails verification' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'legacy data extracts',
        site_key: 'mhc',
        key: 'aca_legacy_data_extracts',
        market_kind: 'any',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )

      expect { described_class.new(file_path: temp_file.path).run }
        .to raise_error(RuntimeError, /production uri/)

      expect(endpoint.reload.credentials).to be_empty
    end

    it 'clears all credentials before failing on a missing endpoint key' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      incomplete_payload = payload.deep_dup
      incomplete_payload['missing_endpoint'] = {
        'uri' => 'sftp://preprod-sftp.example.com/data',
        'credentials' => [
          {
            'credential_kind' => 'sftp',
            'account_name' => 'preprod_sftp_user',
            'pass_phrase' => 'new-preprod-password'
          }
        ]
      }
      temp_file.rewind
      temp_file.truncate(0)
      temp_file.write(incomplete_payload.to_json)
      temp_file.rewind

      configured_endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )
      unconfigured_endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'legacy data extracts',
        site_key: 'mhc',
        key: 'aca_legacy_data_extracts',
        market_kind: 'any',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )

      expect { described_class.new(file_path: temp_file.path).run }
        .to raise_error(RuntimeError, /endpoint missing_endpoint not found/)

      expect(configured_endpoint.reload.credentials).to be_empty
      expect(unconfigured_endpoint.reload.credentials).to be_empty
    end

    it 'rejects malformed credential entries and leaves stored credentials cleared' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      malformed_payload = payload.deep_dup
      malformed_payload['aca_shop_analytics_outbound']['credentials'] = ['not-json']
      temp_file.rewind
      temp_file.truncate(0)
      temp_file.write(malformed_payload.to_json)
      temp_file.rewind

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )

      expect { described_class.new(file_path: temp_file.path).run }
        .to raise_error(ArgumentError, /credential/)

      expect(endpoint.reload.credentials).to be_empty
    end

    it 'updates and decrypts S3 credentials' do
      s3_payload = {
        'aca_shop_analytics_archive' => {
          'uri' => 's3://mhc-preprod-aca-shop-analytics-archive@us-east-1/reports',
          'credentials' => [
            {
              'credential_kind' => 's3',
              'access_key_id' => 'preprod-access-key',
              'secret_access_key' => 'preprod-secret-key'
            }
          ]
        }
      }
      temp_file.rewind
      temp_file.truncate(0)
      temp_file.write(s3_payload.to_json)
      temp_file.rewind

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics archive',
        site_key: 'mhc',
        key: 'aca_shop_analytics_archive',
        market_kind: 'shop',
        uri: 's3://mhc-prod-aca-shop-analytics-archive@us-east-1/reports',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 's3',
            access_key_id: 'prod-access-key',
            secret_access_key: 'prod-secret-key'
          )
        ]
      )

      described_class.new(file_path: temp_file.path).run

      endpoint.reload
      expect(endpoint.uri).to eq('s3://mhc-preprod-aca-shop-analytics-archive@us-east-1/reports')
      expect(endpoint.credentials.first.access_key_id).to eq('preprod-access-key')
      expect(endpoint.credentials.first.secret_access_key).to eq('preprod-secret-key')
    end

    it 'rejects S3 credentials without a secret key and leaves stored credentials cleared' do
      s3_payload = {
        'aca_shop_analytics_archive' => {
          'uri' => 's3://mhc-preprod-aca-shop-analytics-archive@us-east-1/reports',
          'credentials' => [
            {
              'credential_kind' => 's3',
              'access_key_id' => 'preprod-access-key'
            }
          ]
        }
      }
      temp_file.rewind
      temp_file.truncate(0)
      temp_file.write(s3_payload.to_json)
      temp_file.rewind

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics archive',
        site_key: 'mhc',
        key: 'aca_shop_analytics_archive',
        market_kind: 'shop',
        uri: 's3://mhc-prod-aca-shop-analytics-archive@us-east-1/reports',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 's3',
            access_key_id: 'prod-access-key',
            secret_access_key: 'prod-secret-key'
          )
        ]
      )

      expect { described_class.new(file_path: temp_file.path).run }
        .to raise_error(RuntimeError, /blank s3 secret key/)

      expect(endpoint.reload.credentials).to be_empty
    end

    it 'allows a lower environment to use the configured preprod endpoint values' do
      ENV['ENV_NAME'] = 'pvt'

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://prod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'prod_sftp_user',
            pass_phrase: 'prod-password'
          )
        ]
      )

      described_class.new(file_path: temp_file.path).run

      expect(endpoint.reload.uri).to eq('sftp://preprod-sftp.example.com/data')
      expect(endpoint.credentials.first.pass_phrase).to eq('new-preprod-password')
    end

    it 'clears credentials and aborts when an override uri is still production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      production_payload = payload.deep_dup
      production_payload['aca_shop_analytics_outbound']['uri'] = 'sftp://prod-sftp.example.com/data'
      temp_file.rewind
      temp_file.truncate(0)
      temp_file.write(production_payload.to_json)
      temp_file.rewind

      endpoint = TransportProfiles::WellKnownEndpoint.create!(
        title: 'shop analytics outbound',
        site_key: 'mhc',
        key: 'aca_shop_analytics_outbound',
        market_kind: 'shop',
        uri: 'sftp://preprod-sftp.example.com/data',
        credentials: [
          TransportProfiles::Credential.new(
            credential_kind: 'sftp',
            account_name: 'preprod_sftp_user',
            pass_phrase: 'old-preprod-password'
          )
        ]
      )

      expect { described_class.new(file_path: temp_file.path).run }
        .to raise_error(ArgumentError, /production uri/)

      expect(endpoint.reload.credentials).to be_empty
    end

    it 'raises when the environment is production' do
      ENV['ENV_NAME'] = 'prod'
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect { described_class.new(file_path: temp_file.path).run }.to raise_error(SystemExit)
    end
  end
end
