# frozen_string_literal: true

module TransportProfiles
  module Processes
    module Legacy
      class PushGluePlanValidationReport < ::TransportProfiles::Processes::Process

        def initialize(source_uri, gateway, destination_file_name: d_file_name, source_credentials: s_credentials)
          super("Distribute remote glue cca plan validation report", gateway)

          add_step(TransportProfiles::Steps::RouteTo.new(:aca_legacy_data_extracts_archive, source_uri, gateway, destination_file_name: destination_file_name, source_credentials: source_credentials))
          add_step(TransportProfiles::Steps::RouteTo.new(:aca_legacy_data_extracts, source_uri, gateway, destination_file_name: destination_file_name, source_credentials: source_credentials))
        end

        def self.used_endpoints
          [
            :aca_legacy_data_extracts_archive,
            :aca_legacy_data_extracts
          ]
        end
      end
    end
  end
end
