# frozen_string_literal: true

require 'aws-sdk'
require "transport_gateway/engine"

module URI
  class S3 < Generic
    def region
      host
    end

    def key
      return nil if path.nil?

      path.gsub(%r{^/}, '')
    end

    def bucket
      userinfo
    end
  end

  @@schemes ||= {}
  @@schemes['S3'] = S3
end

# Provides the raw underlying plumbing for transfering resources.
#
# You probably don't want this.
#
# If you are looking to create a workflow that moves artifacts, your starting point is subclassing {TransportProfiles::Processes::Process}.
module TransportGateway
end
