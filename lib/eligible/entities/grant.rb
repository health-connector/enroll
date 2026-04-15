# frozen_string_literal: true

module Eligible
  module Entities
    # Entity for Grant
    class Grant < Dry::Struct
      # @!attribute [r] _id
      # An id reference to this Grant
      # @return [String]
      attribute? :_id, Types::String.optional.meta(omittable: true)

      # @!attribute [r] key
      # An unambiguous reference to this Grant
      # @return [Symbol]
      attribute :key, Types::String.meta(omittable: false)

      # @!attribute [r] title
      # A name given to the resource by which the resource is formally known
      # @return [String]
      attribute :title, Types::String.meta(omittable: false)

      # @!attribute [r] description
      # An optional account of the content of this resource
      # @return [String]
      attribute? :description, Types::String.optional.meta(omittable: true)

      # @!attribute [r] value
      # The value associated with the grant
      # @return [Value]
      attribute :value, Eligible::Entities::Value.meta(omittable: false)

      # @!attribute [r] state_histories
      # Collection of resource historical states
      # @return [Array]
      attribute :state_histories,
                Types::Array.of(Eligible::Entities::StateHistory).meta(omittable: false)

      # @!attribute [r] timestamp
      # Timestamp of the resource ie. submitted, created or modified time of the resource
      # @return [Timestamp]
      attribute :timestamps,
                Eligible::Entities::TimeStamp.optional.meta(omittable: true)
    end
  end
end
