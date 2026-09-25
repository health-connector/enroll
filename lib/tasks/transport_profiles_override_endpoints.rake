# frozen_string_literal: true

namespace :transport_profiles do
  desc 'Overwrite lower-environment WellKnownEndpoint URIs and embedded credentials after a prod refresh.'
  task override_preprod_endpoints: :environment do
    TransportProfiles::EndpointOverride.abort_if_production!

    override = TransportProfiles::EndpointOverride.new(
      dry_run: ENV['DRY_RUN'] == 'true'
    )
    override.run
  end
end
