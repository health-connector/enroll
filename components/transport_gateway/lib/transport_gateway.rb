require 'aws-sdk'
require "transport_gateway/engine"

# rubocop:disable Style/ClassVars
module URI
  class S3 < Generic
    def region
      host
    end

    def key
      return nil if path.nil?
      path.gsub(/^\//, '')
    end

    def bucket
      userinfo
    end
  end

  register_scheme "S3", S3
end
# rubocop:enable Style/ClassVars

# Provides the raw underlying plumbing for transfering resources.
#
# You probably don't want this.
# 
# If you are looking to create a workflow that moves artifacts, your starting point is subclassing {TransportProfiles::Processes::Process}.
module TransportGateway
end
