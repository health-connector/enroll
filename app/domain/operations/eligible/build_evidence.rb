# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Eligible
    # Operation to build evidence for eligibility.
    class BuildEvidence
      include Dry::Monads[:do, :result]
      include ::Operations::Eligible::EligibilityImport[
                configuration: "evidence_defaults"
              ]

      # Builds evidence options for eligibility determination.
      #
      # @param [Hash] opts Options to build eligibility.
      # @option opts [GlobalId] :subject (required) The subject for which the evidence is being created.
      # @option opts [String] :evidence_key (required) The key of the evidence.
      # @option opts [String] :evidence_value (required) The value of the evidence.
      # @option opts [Date] :effective_date (required) The effective date of the evidence.
      # @option opts [Hash] :evidence_record (optional) An existing evidence record, if available.
      # @option opts [Hash] :timestamps (optional) Custom timestamps for data migrations.
      #
      # @return [Dry::Monads::Result] Success with evidence options if valid, or Failure with validation errors.
      def call(params)
        values = yield validate(params)
        evidence_options = yield build(values)

        Success(evidence_options)
      end

      private

      def validate(params)
        errors = []
        errors << "subject missing" unless params[:subject]
        errors << "evidence key missing" unless params[:evidence_key]
        errors << "evidence value missing" unless params[:evidence_value]
        errors << "effective date missing" unless params[:effective_date]
        errors << "current_user missing" unless params[:current_user]

        errors.empty? ? Success(params) : Failure(errors)
      end

      def build(values)
        options = build_default_evidence_options(values)
        state_history_options = build_state_history(values)

        options[:state_histories] ||= []
        options[:state_histories] << state_history_options
        options[:is_satisfied] = state_history_options[:is_eligible]
        options[:current_state] = state_history_options[:to_state]

        Success(options)
      end

      def build_default_evidence_options(values)
        if values[:evidence_record]&.persisted?
          options = values[:evidence_record].serializable_hash.deep_symbolize_keys
          options[:subject_ref] = URI(options[:subject_ref]) unless options[:subject_ref].is_a? URI
          options[:evidence_ref] = URI(options[:evidence_ref]) if options[:evidence_ref] && !(options[:evidence_ref].is_a? URI)
          options
        else
          {
            title: configuration.title,
            key: values[:evidence_key],
            subject_ref: values[:subject].uri
          }
        end
      end

      def build_state_history(values)
        recent_record = values[:evidence_record]&.state_histories&.max_by(&:created_at)
        from_state = recent_record&.to_state || :initial
        to_state = configuration.to_state_for(values, from_state)

        options = {
          event: :"move_to_#{to_state}",
          transition_at: DateTime.now,
          effective_on: values[:effective_date],
          from_state: from_state,
          is_eligible: configuration.is_eligible?(to_state),
          to_state: to_state,
          updated_by: values[:current_user].to_s
        }
        options[:timestamps] = values[:timestamps] if values[:timestamps]
        options
      end
    end
  end
end