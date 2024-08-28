# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module BenefitMarkets
  module Operations
    module Pvp
      class CreatePvpEligibility
        send(:include, Dry::Monads[:result, :do])

        attr_accessor :subject

        # @param [ Hash ] params evidence_key, evidence_value, effective_date,
        # subject_global_id and current user.
        # In this case subject_global_id id PremiumValueProduct instants global_id
        # @param [ Hash ] params sub, evidence_value, effective_date
        # @return [ BenefitMarkets::PvpEligibilities::PvpEligibility ]
        def call(params)
          values = yield validate(params)
          eligibility_record = yield find_eligibility
          eligibility_options = yield build_eligibility_options(values, eligibility_record)
          eligibility = yield create_eligibility(eligibility_options)
          eligibility_record = yield store(eligibility)

          Success(eligibility_record)
        end

        private

        def validate(params)
          errors = []
          errors << "evidence key missing" unless params[:evidence_key]
          errors << "evidence value missing" unless params[:evidence_value]
          errors << "effective date missing" unless params[:effective_date].is_a?(::Date)

          @subject = GlobalID::Locator.locate(params[:subject])
          errors << "subject missing or not found for #{params[:subject]}" unless @subject.present?
          errors << "current_user is missing #{params[:current_user]}" unless params[:current_user].present?

          errors.empty? ? Success(params) : Failure(errors)
        end

        def find_eligibility
          eligibility = subject.eligibilities.by_key(:cca_shop_pvp_eligibility).max_by(&:created_at)

          Success(eligibility)
        end

        def build_eligibility_options(values, eligibility_record = nil)
          ::Operations::Eligible::BuildEligibility.new(
            configuration:
              ::BenefitMarkets::Operations::Pvp::PvpEligibilityConfiguration.new(
                subject: subject,
                effective_date: values[:effective_date]
              )
          ).call(
            values.merge(
              eligibility_record: eligibility_record,
              evidence_configuration:
                ::BenefitMarkets::Operations::Pvp::PvpEvidenceConfiguration.new
            )
          )
        end

        # Following Operation expects AcaEntities domain class as subject
        def create_eligibility(eligibility_options)
          ::AcaEntities::Eligible::AddEligibility.new.call(
            subject: "AcaEntities::BenefitMarkets::PremiumValueProduct",
            eligibility: eligibility_options
          )
        end

        def store(eligibility)
          eligibility_record = subject.eligibilities.where(id: eligibility._id).first

          if eligibility_record
            update_eligibility_record(eligibility_record, eligibility)
          else
            eligibility_record = create_eligibility_record(eligibility)
            subject.eligibilities << eligibility_record
          end

          if subject.save
            Success(eligibility_record.reload)
          else
            Failure(subject.errors.full_messages)
          end
        end

        # Here eligibility_record is persested record and
        # eligibility is the new one that got built
        def update_eligibility_record(eligibility_record, eligibility)
          evidence = eligibility.evidences.last
          evidence_history_params = build_history_params_for(evidence)
          eligibility_history_params = build_history_params_for(eligibility)

          evidence_record = eligibility_record.evidences.last
          evidence_record.is_satisfied = evidence.is_satisfied
          evidence_record.current_state = evidence.current_state
          evidence_record.state_histories.build(evidence_history_params)
          eligibility_record.state_histories.build(eligibility_history_params)
          eligibility_record.current_state = eligibility.current_state

          eligibility_record.save
          subject.save
        end

        def build_history_params_for(record)
          record_history = record.state_histories.last
          record_history.to_h
        end

        def create_eligibility_record(eligibility)
          eligibility_params = eligibility.to_h.except(:evidences, :grants)
          eligibility_record = ::BenefitMarkets::PvpEligibilities::PvpEligibility.new(eligibility_params)

          eligibility_record.tap do |record|
            record.evidences = record.class.create_objects(eligibility.evidences, :evidences)
            record.grants = record.class.create_objects(eligibility.grants, :grants)
          end

          eligibility_record
        end
      end
    end
  end
end