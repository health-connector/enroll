# frozen_string_literal: true

module Eligible
  # The Eligibility class models the eligibility status for various entities.
  # It stores the eligibility key, title, description, current state, and
  # embeds related evidence, grants, and state history.
  #
  # This model provides methods to check eligibility status, manage state transitions,
  # and handle grants and evidence specific to the eligibility.
  #
  # @example
  #   eligibility = Eligible::Eligibility.new(key: :example_key, title: "Example Eligibility")
  class Eligibility
    include Mongoid::Document
    include Mongoid::Timestamps
    include GlobalID::Identification

    STATUSES = %i[initial eligible ineligible].freeze

    embedded_in :eligible, polymorphic: true

    field :key, type: Symbol
    field :title, type: String
    field :description, type: String
    field :current_state, type: Symbol, default: :initial

    embeds_many :evidences,
                class_name: "::Eligible::Evidence",
                cascade_callbacks: true

    embeds_many :grants,
                class_name: "::Eligible::Grant",
                cascade_callbacks: true

    embeds_many :state_histories,
                class_name: "::Eligible::StateHistory",
                cascade_callbacks: true,
                as: :status_trackable

    validates_presence_of :title
    validates_uniqueness_of :key

    delegate :effective_on,
             :is_eligible,
             to: :latest_state_history,
             allow_nil: false

    delegate :eligible?,
             :is_eligible_on?,
             :eligible_periods,
             to: :decorated_eligible_record,
             allow_nil: true

    scope :by_key, ->(key) { where(key: key.to_sym) }
    scope :eligible, -> { where(current_state: :eligible) }
    scope :ineligible, -> { where(current_state: :ineligible) }

    # Returns the latest state history record
    #
    # @return [Eligible::StateHistory] The most recent state history
    def latest_state_history
      state_histories.max_by(&:created_at)
    end

    # Returns the active state for eligibility
    #
    # @return [Symbol] The active state (:eligible)
    def active_state
      :eligible
    end

    # Returns the inactive state for eligibility
    #
    # @return [Symbol] The inactive state (:ineligible)
    def inactive_state
      :ineligible
    end

    # Checks if the current state is eligible
    #
    # @return [Boolean] True if current state is eligible, false otherwise
    def eligible?
      current_state == active_state
    end

    # Returns a decorated eligible record with periods of eligibility
    #
    # @return [EligiblePeriodHandler] A decorated record for eligibility periods
    def decorated_eligible_record
      EligiblePeriodHandler.new(self)
    end

    # Finds a grant by its key
    #
    # @param [String] grant_key The key of the grant to look up
    # @return [Eligible::Grant, nil] The grant object, or nil if not found
    def grant_for(grant_key)
      grants.detect { |grant| grant.value&.item&.to_s == grant_key.to_s }
    end

    class << self
      ResourceReference = Struct.new(:class_name, :optional, :meta)

      RESOURCE_KINDS = [
        BenefitMarkets::PvpEligibilities::AdminAttestedEvidence,
        BenefitMarkets::PvpEligibilities::PvpGrant,
        Eligible::Evidence,
        Eligible::Grant
      ].freeze

      # A directory to store registered resource references
      # @return [Concurrent::Map] The resource reference directory
      def resource_ref_dir
        @resource_ref_dir ||= Concurrent::Map.new
      end

      # Registers a resource kind under a given name with options
      #
      # @param [Symbol] resource_kind The type of resource (e.g., :grant, :evidence)
      # @param [String] name The name of the resource
      # @param [Hash] options The options for the resource (e.g., class_name, optional, meta)
      def register(resource_kind, name, options)
        resource_set = resource_kind.to_s.pluralize
        resource_ref_dir[resource_set.to_sym] ||= {}
        resource_ref_dir[resource_set.to_sym][name] = ResourceReference.new(
          options[:class_name],
          options[:optional],
          options[:meta]
        )
      end

      # Registers a grant resource
      #
      # @param [String] name The name of the grant
      # @param [Hash] options Options for the grant (e.g., class_name, optional, meta)
      def grant(name, **options)
        register(:grant, name, options)
      end

      # Registers an evidence resource
      #
      # @param [String] name The name of the evidence
      # @param [Hash] options Options for the evidence (e.g., class_name, optional, meta)
      def evidence(name, **options)
        register(:evidence, name, options)
      end

      # Retrieves the resource class name for evidences
      #
      # @param [Symbol] key The key for the evidence resource
      # @return [String] The class name for the evidence resource
      def evidences_resource_for(key)
        resource_ref_dir[:evidences]&.dig(key)&.class_name || "Eligible::Evidence"
      end

      # Retrieves the resource class name for grants
      #
      # @param [Symbol] key The key for the grant resource
      # @return [String] The class name for the grant resource
      def grants_resource_for(key)
        resource_ref_dir[:grants]&.dig(key)&.class_name || "Eligible::Grant"
      end

      # Creates objects from the given collection for the specified type (grant or evidence)
      #
      # @param [Array] collection A collection of objects (e.g., grants, evidences)
      # @param [Symbol] type The type of object (e.g., :grant, :evidence)
      # @return [Array] Array of created objects
      def create_objects(collection, type)
        collection.map do |item|
          resource_name = send("#{type}_resource_for", item.key)
          item_class = RESOURCE_KINDS.find do |kind|
            kind.name == (resource_name.sub(/^::/, ""))
          end

          next unless item_class

          item_class.new(item.to_h)
        end.compact
      end
    end
  end
end
