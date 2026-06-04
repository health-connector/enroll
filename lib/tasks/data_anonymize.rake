# frozen_string_literal: true

require_relative '../data_anonymization/anonymized_data'
require_relative '../data_anonymization/runner'
require_relative '../data_anonymization/verifier'

# @!group Data Anonymization Tasks
#
# Anonymizes all PII in the current CCA database. Restore a production backup
# into a lower environment, run the anonymizer, verify, then dump and share.
#
# == Typical workflow
#
#   1. Restore a prod backup into the lower env database.
#   2. Run data:anonymize:reset if a prior sentinel exists (fresh DB refresh).
#   3. Run data:anonymize (dry-run first, then live).
#   4. Run data:anonymize:verify to confirm PII is gone.
#   5. Dump and share the anonymized database.
#
# == ENV_NAME requirement
#
# ENV_NAME must be set to a non-'prod' value (e.g. 'pvt', 'preprod').
# The task ABORTS immediately if ENV_NAME is unset or empty — this is an
# intentional fail-closed safety guard to prevent accidental production runs
# when the environment signal is missing or ambiguous.
# In k8s lower envs, ENV_NAME and ENROLL_REVIEW_ENVIRONMENT are injected
# automatically by the mhc_k8s configmap; no manual export is needed.
#
# @example Dry-run first — preview record counts without writing anything
#   ENV_NAME=pvt bundle exec rake data:anonymize DRY_RUN=true
#
# @example Standard live run
#   ENV_NAME=pvt bundle exec rake data:anonymize SKIP_CONFIRMATION=true
#
# @example Verify PII was removed after the run
#   ENV_NAME=pvt bundle exec rake data:anonymize:verify
#
# @example Reset anonymizer state after a fresh DB refresh from a prior environment
#   ENV_NAME=pvt bundle exec rake data:anonymize:reset
#
# @example Drop history_trackers only (e.g. after Sidekiq activity post-run)
#   ENV_NAME=pvt bundle exec rake data:anonymize:drop_history_trackers
#
# @example Force re-anonymize an already-anonymized database
#   ENV_NAME=pvt bundle exec rake data:anonymize FORCE_REANONYMIZE=true SKIP_CONFIRMATION=true
#
# @example Opt in to anonymizing location and DOB fields (off by default to protect rating/eligibility)
#   ENV_NAME=pvt bundle exec rake data:anonymize ANONYMIZE_ZIP=true ANONYMIZE_COUNTY=true ANONYMIZE_STATE=true ANONYMIZE_DOB=true
#
# @example Lower k8s env — ENV_NAME and ENROLL_REVIEW_ENVIRONMENT injected by configmap
#   bundle exec rake data:anonymize SKIP_CONFIRMATION=true
#
# @example Out-of-process prehash re-verification using credentials printed at run time
#   bundle exec rake data:anonymize:verify RUN_ID=<uuid> HMAC_KEY=<hex>
#
# == Environment variables
#
# @env ENV_NAME                  [String]  Required. k8s environment name (mhc_k8s configmap).
#   Must be set and must NOT equal 'prod'. Omitting this causes an immediate safety abort.
#   Use 'pvt' or 'preprod' locally; injected automatically in k8s.
# @env ENROLL_REVIEW_ENVIRONMENT [Boolean] Required in deployed lower envs (Rails.env=production).
#   Must be 'true' to distinguish lower envs from real prod. Not required locally (Rails.env=test).
# @env SKIP_CONFIRMATION [Boolean] Set to 'true' to skip the YES_ANONYMIZE interactive prompt
# @env DRY_RUN           [Boolean] Set to 'true' to preview counts without writing
# @env BATCH_SIZE        [Integer] Documents per bulk_write batch (default: 1000)
# @env FORCE_REANONYMIZE [Boolean] Set to 'true' to bypass the idempotency guard
# @env ANONYMIZE_ZIP     [Boolean] Anonymize zip fields (off by default — protects rating calculations)
# @env ANONYMIZE_COUNTY  [Boolean] Anonymize county fields (off by default — protects rating calculations)
# @env ANONYMIZE_DOB     [Boolean] Shift DOB ±30 days (off by default — protects age-band eligibility)
# @env ANONYMIZE_STATE   [Boolean] Anonymize state fields (off by default — protects plan availability)
# @env RUN_ID            [String]  UUID printed at end of a successful run; pass to :verify for re-verification
# @env HMAC_KEY          [String]  Hex key printed at end of a successful run; pass to :verify for re-verification
# @!endgroup

namespace :data do
  desc "Anonymize all PII data in the current database (CCA). NOT safe for production."
  task :anonymize => :environment do
    DataAnonymizer::Runner.new(
      batch_size: ENV.fetch('BATCH_SIZE', 1000).to_i,
      dry_run: ENV.fetch('DRY_RUN', 'false') == 'true',
      force: ENV.fetch('FORCE_REANONYMIZE', 'false') == 'true',
      anonymize_zip: ENV.fetch('ANONYMIZE_ZIP', 'false') == 'true',
      anonymize_county: ENV.fetch('ANONYMIZE_COUNTY', 'false') == 'true',
      anonymize_dob: ENV.fetch('ANONYMIZE_DOB', 'false') == 'true',
      anonymize_state: ENV.fetch('ANONYMIZE_STATE', 'false') == 'true'
    ).run
  end

  namespace :anonymize do
    desc "Generate a verification report confirming PII has been anonymized.
          Optionally pass RUN_ID and HMAC_KEY to re-run canonical prehash checks
          out-of-process (requires the key printed/saved at anonymization time)."
    task :verify => :environment do
      verifier_opts = { mode: :audit }
      verifier_opts[:run_id] = ENV['RUN_ID'] if ENV['RUN_ID'].present?
      verifier_opts[:hmac_key] = ENV['HMAC_KEY'] if ENV['HMAC_KEY'].present?
      DataAnonymizer::Verifier.new(**verifier_opts).run
    end

    desc "Drop the history_trackers collection. Use to clean up tracker docs
          written by app/sidekiq activity after an anonymization run, before
          re-running data:anonymize:verify. Honors the same production-safety
          guard as data:anonymize."
    task :drop_history_trackers => :environment do
      # Reuse Runner's production-safety guard rather than duplicating the
      # multi-signal check here. The +force: true+ flag bypasses idempotency,
      # which is not consulted by abort_if_production!.
      DataAnonymizer::Runner.new(force: true).send(:abort_if_production!)

      db = Mongoid.default_client.database
      if db.collection_names.include?('history_trackers')
        count = db[:history_trackers].count_documents({})
        db[:history_trackers].drop
        Rails.logger.info "[data:anonymize:drop_history_trackers] Dropped history_trackers (#{count} documents) from #{db.name}"
        puts "Dropped history_trackers (#{count} documents) from #{db.name}"
      else
        Rails.logger.info "[data:anonymize:drop_history_trackers] history_trackers not present in #{db.name}; nothing to drop"
        puts "history_trackers not present in #{db.name}; nothing to drop"
      end
    end

    desc "Drop the anonymizer-owned bookkeeping collections
          (data_anonymizer_runs sentinel and data_anonymizer_prehashes TTL).
          Use after a fresh DB refresh from a prior environment so the next
          data:anonymize run is not blocked by a stale sentinel. Honors the
          same production-safety guard as data:anonymize."
    task :reset => :environment do
      # Reuse Runner's production-safety guard. +force: true+ bypasses
      # idempotency, which is not consulted by abort_if_production!.
      DataAnonymizer::Runner.new(force: true).send(:abort_if_production!)

      db = Mongoid.default_client.database
      %w[data_anonymizer_runs data_anonymizer_prehashes].each do |name|
        if db.collection_names.include?(name)
          count = db[name].count_documents({})
          db[name].drop
          Rails.logger.info "[data:anonymize:reset] Dropped #{name} (#{count} documents) from #{db.name}"
          puts "Dropped #{name} (#{count} documents) from #{db.name}"
        else
          Rails.logger.info "[data:anonymize:reset] #{name} not present in #{db.name}; nothing to drop"
          puts "#{name} not present in #{db.name}; nothing to drop"
        end
      end
    end
  end
end
