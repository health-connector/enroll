# frozen_string_literal: true

# require 'uri'
require 'cgi'
require 'dry-types'

module BenefitSponsors
  module Types
    send(:include, Dry.Types())
    include Dry::Logic

    Bson = Types.Constructor(BSON::ObjectId) { |val| BSON::ObjectId val } unless Types.const_defined?('Bson')
  end
end
