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

      described_class.new(file_path: temp_file.path, dry_run: true).run

      endpoint.reload
      expect(endpoint.uri).to eq('sftp://prod-sftp.example.com/data')
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
        .to raise_error(RuntimeError, /production uri/)

      expect(endpoint.reload.credentials).to be_empty
    end

    it 'raises when the environment is production' do
      ENV['ENV_NAME'] = 'prod'
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect { described_class.new(file_path: temp_file.path).run }.to raise_error(SystemExit)
    end
  end
end
