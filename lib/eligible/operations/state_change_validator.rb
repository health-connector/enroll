# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Eligible
  module Operations
    # Validate state changes on eligibility models
    class StateChangeValidator
      PastState = Struct.new(:effective_on, :is_eligible, :from_state, :to_state, :event)

      CurrentState = Struct.new(
        :effective_on,
        :is_eligible,
        :from_state,
        :to_state,
        :event
      ) do
        attr_accessor :resource, :errors

        def validate
          validate_event
          validate_transition
          validate_is_eligible
        end

        def validate_event
          return if resource::EVENTS.include?(event)

          register_error("invalid event: #{event}")
        end

        def validate_transition
          valid_transitions = resource::STATE_TRANSITION_MAP[to_state]
          return if valid_transitions&.include?(from_state)

          register_error(
            "invalid transition from #{from_state} to #{to_state}"
          )
        end

        def validate_is_eligible
          if resource::ELIGIBLE_STATUSES.include?(to_state) && !is_eligible
            register_error("is_eligible must be true for #{to_state}")
          elsif resource::INELIGIBLE_STATUSES.include?(to_state) && is_eligible
            register_error("is_eligible must be false for #{to_state}")
          end
        end

        def register_error(error_message)
          @errors ||= []
          @errors << error_message
        end
      end

      attr_reader :past, :current, :errors

      def initialize(state_histories, resource)
        @errors = []
        history = state_histories.last
        @current = CurrentState.new(
          history[:effective_on],
          history[:is_eligible],
          history[:from_state],
          history[:to_state],
          history[:event]
        )
        @current.resource = resource
        @current.errors = []

        @past = state_histories[0..-2].map do |h|
          PastState.new(
            h[:effective_on],
            h[:is_eligible],
            h[:from_state],
            h[:to_state],
            h[:event]
          )
        end
      end

      def validate
        validate_current
        validate_past_history
      end

      def validate_current
        current.validate
        @errors += current.errors if current.errors.any?
      end

      def validate_past_history
        return if past.empty?

        past.each_with_index do |state, index|
          next_state = index + 1 < past.size ? past[index + 1] : current

          @errors << "state mismatch: #{state.to_state} != #{next_state.from_state}" unless state.to_state == next_state.from_state
        end
      end
    end
  end
end
