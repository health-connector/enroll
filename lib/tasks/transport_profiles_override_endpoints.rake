# frozen_string_literal: true

# @!group Transport profile endpoint override
#
# Replaces endpoint URIs and credentials restored from prod with values from a
# secret-mounted JSON file. Run only in preprod after the database refresh.
# Invalid input leaves credentials cleared.
#
# Set TRANSPORT_ENDPOINT_OVERRIDE_FILE to use a different file than the default.
# Check changes with DRY_RUN=true, then rerun without DRY_RUN to apply them.
#
# @example Preview
#   ENV_NAME=preprod bundle exec rake transport_profiles:override_preprod_endpoints DRY_RUN=true
# @example Apply
#   ENV_NAME=preprod bundle exec rake transport_profiles:override_preprod_endpoints
# @!endgroup
namespace :transport_profiles do
  desc 'Apply configured WellKnownEndpoint URIs and credentials after a prod refresh in preprod.'
  task override_preprod_endpoints: :environment do
    TransportProfiles::EndpointOverride.ensure_preprod_environment!

    override = TransportProfiles::EndpointOverride.new(
      dry_run: ENV['DRY_RUN'] == 'true'
    )
    override.run
  end
end
