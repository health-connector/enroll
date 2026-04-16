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
        return build_new_evidence_options(values) unless values[:evidence_record]&.persisted?

        options = values[:evidence_record].serializable_hash.deep_symbolize_keys
        normalize_evidence_options!(options, values)
        options
      end

      def build_new_evidence_options(values)
        {
          title: configuration.title,
          key: values[:evidence_key].to_s,
          subject_ref: values[:subject].uri
        }
      end

      def normalize_evidence_options!(options, values)
        convert_ids_to_strings!(options)
        options[:subject_ref] = normalize_subject_ref(options[:subject_ref], values[:subject])
        options[:evidence_ref] = normalize_evidence_ref(options[:evidence_ref])
      end

      def convert_ids_to_strings!(options)
        options[:_id] = options[:_id].to_s if options[:_id]

        return unless options[:state_histories].is_a?(Array)

        options[:state_histories].each do |state_history|
          state_history[:_id] = state_history[:_id].to_s if state_history[:_id]
        end
      end

      def normalize_subject_ref(subject_ref, subject)
        return subject.uri if subject_ref.blank?
        return subject_ref if subject_ref.is_a?(URI)

        safe_uri_conversion(subject_ref, fallback: subject.uri)
      end

      def normalize_evidence_ref(evidence_ref)
        return nil if evidence_ref.blank?
        return evidence_ref if evidence_ref.is_a?(URI)

        safe_uri_conversion(evidence_ref, fallback: nil)
      end

      def safe_uri_conversion(value, fallback:)
        URI(value)
      rescue URI::InvalidURIError
        fallback
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