class SamlInformation

  class MissingKeyError < StandardError
    def initialize(key)
      super("Missing required key: #{key}")
    end
  end

  include Singleton

  REQUIRED_KEYS = [
    'assertion_consumer_service_url',
    'assertion_consumer_logout_service_url',
    'issuer',
    'idp_entity_id',
    'idp_sso_target_url',
    'idp_slo_target_url',
    'idp_cert',
    'name_identifier_format',
    'idp_cert_fingerprint',
    'idp_cert_fingerprint_algorithm',
    'curam_landing_page_url',
    'saml_logout_url',
    'account_conflict_url',
    'account_recovery_url',
    'iam_login_url',
    'curam_broker_dashboard'
  ]

  attr_reader :config

  # TODO: I have a feeling we may be using this pattern
  #       A LOT.  Look into extracting it if we repeat.
  def initialize
    @config = YAML.safe_load(ERB.new(File.read(File.join(Rails.root,'config', 'saml.yml'))).result(binding))
    ensure_configuration_values(@config)
  end

  def ensure_configuration_values(conf)
    REQUIRED_KEYS.each do |k|
      if @config[k].blank?
        raise MissingKeyError.new(k)
      end
    end
  end

  def self.define_key(key)
    define_method(key.to_sym) do
      config[key.to_s]
    end
    self.instance_eval(<<-RUBYCODE)
      def self.#{key.to_s}
        self.instance.#{key.to_s}
      end
    RUBYCODE
  end

  REQUIRED_KEYS.each do |k|
    define_key k
  end

  private

  # Method for use in consumed ERB
  # Returns val unless blank, otherwise for non-prod envs, returns default. Else, nil.
  # In prod mode, we want to validate the required keys are present and not accidentally fallback to junk values. In
  # development, this is less important.
  def val_or_nonprod_default(val, nonprod_default)
    return val if val.present?
    nonprod_default unless Rails.env.production
  end
end
