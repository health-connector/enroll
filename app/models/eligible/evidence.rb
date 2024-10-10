# frozen_string_literal: true

module Eligible
  # The Evidence class represents an individual piece of evidence
  # that is part of the eligibility determination process.
  #
  # Each evidence has a state (e.g., approved, denied) and tracks
  # state transitions via state histories. It also checks whether
  # the evidence is eligible based on its current state.
  #
  # @example
  #   eligibility.evidences.build(title: "Income Verification", key: :income, is_satisfied: true)
  class Evidence
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :eligibility, class_name: "::Eligible::Eligibility"

    STATUSES = %i[initial not_approved approved denied].freeze
    ELIGIBLE_STATUSES = %i[approved].freeze

    field :key, type: Symbol
    field :title, type: String
    field :description, type: String
    field :is_satisfied, type: Boolean, default: false
    field :current_state, type: Symbol, default: :initial
    field :subject_ref, type: String
    field :evidence_ref, type: String

    embeds_many :state_histories,
                class_name: "::Eligible::StateHistory",
                cascade_callbacks: true,
                as: :status_trackable

    validates_presence_of :title, :key, :is_satisfied

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

    # Returns the most recent state history record
    #
    # @return [Eligible::StateHistory] The latest state history
    def latest_state_history
      state_histories.max_by(&:created_at)
    end

    # Defines the active state for evidence (approved)
    #
    # @return [Symbol] The active state
    def active_state
      :approved
    end

    # Defines the inactive state for evidence (denied)
    #
    # @return [Symbol] The inactive state
    def inactive_state
      :denied
    end

    # Checks if the evidence is currently in an eligible state
    #
    # @return [Boolean] True if the current state is active (approved), false otherwise
    def eligible?
      current_state == active_state
    end

    # Returns a decorated eligible record for handling eligibility periods
    #
    # @return [Eligible::EligiblePeriodHandler] The decorated eligible record
    def decorated_eligible_record
      EligiblePeriodHandler.new(self)
    end
  end
end
