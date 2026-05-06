# frozen_string_literal: true

require_relative '../data_anonymization/fake_data'
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
# @env BATCH_SIZE        [Integer] Documents per bulk_write batch (default: 1000)
# @env DRY_RUN           [Boolean] Set to 'true' to preview without writing
# @env SKIP_CONFIRMATION [Boolean] Set to 'true' to skip the YES_ANONYMIZE prompt
# @env FORCE_REANONYMIZE [Boolean] Set to 'true' to bypass the idempotency guard
# @env ANONYMIZE_ZIP     [Boolean] Set to 'true' to overwrite `zip` fields (default: preserve)
# @env ANONYMIZE_COUNTY  [Boolean] Set to 'true' to overwrite `county` fields (default: preserve)
# @!endgroup

namespace :data do
  desc "Anonymize all PII data in the current database (CCA). NOT safe for production."
  task :anonymize => :environment do
    DataAnonymizer::Runner.new(
      batch_size: (ENV['BATCH_SIZE'] || 1000).to_i,
      dry_run: ENV['DRY_RUN'] == 'true',
      force: ENV['FORCE_REANONYMIZE'] == 'true',
      anonymize_zip: ENV['ANONYMIZE_ZIP'] == 'true',
      anonymize_county: ENV['ANONYMIZE_COUNTY'] == 'true'
    ).run
  end

  namespace :anonymize do
    desc "Generate a verification report confirming PII has been anonymized"
    task :verify => :environment do
      DataAnonymizer::Verifier.new.run
    end
  end
end
