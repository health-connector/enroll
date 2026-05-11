# frozen_string_literal: true

module Eligible
  module Entities
    # Entity class for Evidence
    class Evidence < Dry::Struct
      INELIGIBLE_STATUSES = %i[initial not_approved denied].freeze
      ELIGIBLE_STATUSES = %i[approved].freeze
      EVENTS = %i[
        move_to_not_approved
        move_to_approved
        move_to_denied
      ].freeze

      STATE_TRANSITION_MAP = {
        not_approved: [:initial],
        approved: %i[initial not_approved approved denied],
        denied: %i[initial not_approved approved denied]
      }.freeze

      # @!attribute [r] _id
      # An id reference to this Evidence
      # @return [String]
      attribute? :_id, Types::String.optional.meta(omittable: true)

      # @!attribute [r] key
      # An unambiguous reference to this Evidence
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

      # @!attribute [r] current_state
      # CurrentState of the resource
      # @return [Symbol]
      attribute :current_state, Types::Symbol.meta(omittable: false)

      # @!attribute [r] is_satisfied
      # Is the evidence satisfied?
      # @return [Boolean]
      attribute :is_satisfied, Types::Bool.optional.meta(omittable: false)

      # @!attribute [r] state_histories
      # Collection of resource historical states and associated eligibility
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
