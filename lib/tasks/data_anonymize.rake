# frozen_string_literal: true

require_relative '../data_anonymization/anonymized_data'
require_relative '../data_anonymization/runner'
require_relative '../data_anonymization/verifier'

# @!group Data Anonymization Tasks
#
# Anonymizes all PII in the current CCA database. Restore a production backup
# into a lower environment, run the anonymizer, verify, then dump and share.
#
# @example Standard run (local dev — ENV_NAME required by the production guard)
#   ENV_NAME=pvt bundle exec rake data:anonymize
#
# @example Dry-run (preview counts without writing)
#   ENV_NAME=pvt bundle exec rake data:anonymize DRY_RUN=true
#
# @example CI/CD pipeline (skip interactive prompt, larger batch)
#   ENV_NAME=pvt bundle exec rake data:anonymize SKIP_CONFIRMATION=true BATCH_SIZE=2000
#
# @example Re-run on an already-anonymized database
#   ENV_NAME=pvt bundle exec rake data:anonymize FORCE_REANONYMIZE=true SKIP_CONFIRMATION=true
#
# @example Lower k8s env (ENV_NAME and ENROLL_REVIEW_ENVIRONMENT are injected by configmaps)
#   bundle exec rake data:anonymize SKIP_CONFIRMATION=true
#
# @example Verify after anonymization
#   bundle exec rake data:anonymize:verify
#
# @example Reset anonymizer state after a fresh DB refresh from a prior environment
#   ENV_NAME=pvt bundle exec rake data:anonymize:reset
#
# @example Opt in to anonymizing sensitive location and DOB fields
#   ENV_NAME=pvt bundle exec rake data:anonymize ANONYMIZE_ZIP=true ANONYMIZE_COUNTY=true ANONYMIZE_STATE=true ANONYMIZE_DOB=true
#
# @env ENV_NAME                  [String]  k8s environment name (from mhc_k8s configmap). Must be
#   set and must NOT equal 'prod'. Use 'pvt' or 'preprod' locally; injected by configmap in k8s.
# @env ENROLL_REVIEW_ENVIRONMENT [Boolean] Must be 'true' in deployed lower envs (Rails.env=production).
#   Set by k8s configmap to distinguish lower envs from real prod. Not required locally (Rails.env=test).
# @env BATCH_SIZE        [Integer] Documents per bulk_write batch (default: 1000)
# @env DRY_RUN           [Boolean] Set to 'true' to preview without writing
# @env SKIP_CONFIRMATION [Boolean] Set to 'true' to skip the YES_ANONYMIZE prompt
# @env FORCE_REANONYMIZE [Boolean] Set to 'true' to bypass the idempotency guard
# @env ANONYMIZE_ZIP     [Boolean] Anonymize zip fields; preserved by default to protect rating calculations
# @env ANONYMIZE_COUNTY  [Boolean] Anonymize county fields; preserved by default to protect rating calculations
# @env ANONYMIZE_DOB     [Boolean] Shift DOB fields ±30 days; preserved by default to protect age-band eligibility
# @env ANONYMIZE_STATE   [Boolean] Anonymize state fields; preserved by default to protect plan availability
# @env RUN_ID            [String]  Printed to stdout at the end of a successful data:anonymize run; pass to data:anonymize:verify for out-of-process re-verification
# @env HMAC_KEY          [String]  Printed to stdout at the end of a successful data:anonymize run; pass to data:anonymize:verify for out-of-process re-verification
#
# @example Out-of-process canonical prehash re-verification
#   bundle exec rake data:anonymize:verify RUN_ID=<uuid> HMAC_KEY=<hex>
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
