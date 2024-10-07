# frozen_string_literal: true

module Eligible
  # The StateHistory class tracks the transitions between states for an eligible record.
  #
  # Each state history records details such as the effective date, whether the state is eligible,
  # the states being transitioned from and to, and the event that caused the transition. It also
  # tracks the user who updated the state, along with optional comments and reasons for the transition.
  #
  # @example
  #   eligibility.state_histories.build(
  #     effective_on: Date.today,
  #     from_state: :initial,
  #     to_state: :eligible,
  #     is_eligible: true,
  #     transition_at: DateTime.now,
  #     updated_by: "user@example.com"
  #   )
  class StateHistory
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :status_trackable, polymorphic: true

    field :effective_on, type: Date
    field :is_eligible, type: Boolean, default: false

    field :from_state, type: Symbol
    field :to_state, type: Symbol
    field :transition_at, type: DateTime
    field :updated_by, type: String

    field :event, type: Symbol
    field :comment, type: String
    field :reason, type: String

    validates_presence_of :effective_on,
                          :is_eligible,
                          :from_state,
                          :to_state,
                          :transition_at

    scope :by_state, ->(state) { where(to_state: state.to_sym) }
    scope :non_initial, -> { where(:to_state.ne => :initial) }
    scope :eligible, -> { where(:is_eligible => true) }

    def timestamps=(timestamps)
      self.transition_at = timestamps[:modified_at]
      self.created_at = timestamps[:created_at]
      self.updated_at = timestamps[:modified_at]
    end
  end
end
