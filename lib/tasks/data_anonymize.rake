# frozen_string_literal: true

require_relative '../data_anonymization/anonymized_data'
require_relative '../data_anonymization/runner'
require_relative '../data_anonymization/verifier'

# @!group Data Anonymization Tasks
#
# Anonymizes all PII in the current CCA database. Restore a production backup
# into a lower environment, run the anonymizer, verify, then dump and share.
#
# @example Standard run
#   bundle exec rake data:anonymize
#
# @example Dry-run (preview counts without writing)
#   bundle exec rake data:anonymize DRY_RUN=true
#
# @example CI/CD pipeline (skip interactive prompt, larger batch)
#   bundle exec rake data:anonymize SKIP_CONFIRMATION=true BATCH_SIZE=2000
#
# @example Re-run on an already-anonymized database
#   bundle exec rake data:anonymize FORCE_REANONYMIZE=true SKIP_CONFIRMATION=true
#
# @example Verify after anonymization
#   bundle exec rake data:anonymize:verify
#
# @example Opt in to anonymizing sensitive location and DOB fields
#   bundle exec rake data:anonymize ANONYMIZE_ZIP=true ANONYMIZE_COUNTY=true ANONYMIZE_STATE=true ANONYMIZE_DOB=true
#
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
  end
end
