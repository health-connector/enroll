# frozen_string_literal: true

module Operations
  module Eligible
    # This class defines the base configuration for handling eligibility logic.
    # It provides a general structure for eligibility keys, titles, grants, and
    # state determination based on evidences.
    #
    # @example
    #   Operations::Eligible::EligibilityConfiguration.new.key
    #   # => :eligibility
    class EligibilityConfiguration
      # Returns the key that represents the eligibility configuration
      #
      # @return [Symbol] The key for the eligibility configuration
      def key
        :eligibility
      end

      # Returns the title of the eligibility configuration
      #
      # @return [String] The title for the eligibility configuration
      def title
        "Eligibility"
      end

      # Returns a list of default grants for eligibility
      #
      # @return [Array<Array<String>>] Array of grants, each containing a key and description
      def grants
        [["default_grant", "Default Grant"]]
      end

      # Determines the overall state for the given evidences.
      #
      # This method inspects the state histories of the provided evidences and
      # returns `:eligible` if all evidences are approved; otherwise, it returns `:ineligible`.
      #
      # @param [Array<Hash>] evidences_options A list of evidences with their state histories
      # @option evidences_options [Array<Hash>] :state_histories The history of state transitions for an evidence
      #
      # @return [Symbol] The resulting state, either `:eligible` or `:ineligible`
      def to_state_for(evidences_options)
        evidence_states = evidences_options.collect do |evidence_options|
          latest_history = evidence_options[:state_histories].last
          next unless latest_history

          latest_history[:to_state]
        end.compact

        return :eligible if evidence_states.all? { |state| state == :approved }

        :ineligible
      end
    end
  end
end
