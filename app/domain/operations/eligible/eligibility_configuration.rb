# frozen_string_literal: true

module Operations
  module Eligible
    # Configurations for the Eligibility
    class EligibilityConfiguration
      def key
        :eligibility
      end

      def title
        "Eligibility"
      end

      def grants
        [["default_grant", "Default Grant"]]
      end

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