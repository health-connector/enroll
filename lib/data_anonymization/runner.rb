# frozen_string_literal: true

require_relative 'anonymized_data'
require_relative 'canonical_payloads'
require_relative '../timing_helper'
require 'openssl'
require 'securerandom'

module DataAnonymizer
  # Orchestrates all anonymization phases across CCA Mongoid collections.
  #
  # Phases are executed in dependency order: people first (because Phase 3 reads
  # their already-anonymized values via {#build_person_values_map_for_census}),
  # then users, census members, and organizations.
  #
  # @example
  #   runner = DataAnonymizer::Runner.new(batch_size: 500)
  #   runner.run
  # rubocop:disable Metrics/ClassLength
  class Runner
    include CanonicalPayloads
    include TimingHelper

    # Pattern matching email addresses produced by {AnonymizedData.email}.
    # Built from {AnonymizedData::ALLOWED_EMAIL_DOMAINS} so the two stay in
    # lockstep - used to detect a stale sentinel after a partial DB refresh.
    ANONYMIZED_EMAIL_PATTERN = /@(?:#{AnonymizedData::ALLOWED_EMAIL_DOMAINS.map { |d| Regexp.escape(d) }.join('|')})\z/i

    # Number of person/user documents to sample when checking whether a
    # sentinel is stale (a DB refresh from a prior environment restores data
    # collections but does not touch +data_anonymizer_runs+).
    STALE_SENTINEL_SAMPLE_SIZE = 5

    # System operator accounts whose User + linked Person are intentionally
    # preserved through anonymization so a developer can sign in to the
    # post-anonymization dump and exercise the UI without having to seed an
    # admin account first. After phases run (and before the verifier), these
    # users have their password reset and super_admin role ensured by
    # {#ensure_protected_users!}.
    #
    # NOTE: The +admin@dc.gov+ address is intentional - this account is the
    # shared system-operator seed used by the MA codebase and carries a dc.gov
    # domain by convention inherited from the original codebase. It is not a
    # DC-client artifact or a typo.
    PROTECTED_OIM_IDS = %w[admin@dc.gov].freeze

    # Password the protected operator account(s) are reset to after every
    # successful anonymization run. Known-non-secret; for use only in
    # non-prod environments (the runner aborts in production).
    PROTECTED_USER_PASSWORD = 'aA1!aA1!aA1!'

    attr_reader :batch_size, :client, :db

    # @param batch_size [Integer] documents per bulk_write batch (default 1000).
    #   Larger values improve throughput at the cost of memory.
    # @param dry_run [Boolean] when true, logs actions without writing to the database.
    # @param force [Boolean] when true, skips the idempotency guard and re-anonymizes.
    # @param anonymize_zip [Boolean] opt in to anonymize zip; preserved by default to protect rating calculations.
    # @param anonymize_county [Boolean] opt in to anonymize county; preserved by default to protect rating calculations.
    # @param anonymize_dob [Boolean] opt in to shift DOB +/-30 days; preserved by default to protect age-band eligibility.
    # @param anonymize_state [Boolean] opt in to anonymize state; preserved by default to protect plan availability.
    # rubocop:disable Metrics/ParameterLists
    def initialize(batch_size: 1000, dry_run: false, force: false,
                   anonymize_zip: false, anonymize_county: false,
                   anonymize_dob: false, anonymize_state: false)
      @batch_size = batch_size
      @dry_run = dry_run
      @force = force
      @anonymize_zip = anonymize_zip
      @anonymize_county = anonymize_county
      @anonymize_dob = anonymize_dob
      @anonymize_state = anonymize_state
      @client = Mongoid.default_client
      @db = @client.database
      @reference_date = TimeKeeper.date_of_record
    end
    # rubocop:enable Metrics/ParameterLists

    # Production-safety guard callable without a full Runner instance.
    # Reads ENV and the default Mongo database name directly. The rake tasks
    # that need only this check call it here rather than constructing a Runner.
    #
    # @raise [SystemExit] if any signal indicates this is, or might be, real production
    def self.abort_if_production!
      env_name = ENV.fetch('ENV_NAME', nil)
      enroll_review_env = ENV.fetch('ENROLL_REVIEW_ENVIRONMENT', nil)
      db_name = Mongoid.default_client.database.name
      reasons = env_name_reasons(env_name)

      reasons << "Rails.env=production and ENROLL_REVIEW_ENVIRONMENT=#{enroll_review_env.inspect} (expected 'true' in lower envs)" if Rails.env.production? && enroll_review_env != 'true'

      reasons << "database name '#{db_name}' ends in _prod (production pattern)" if db_name =~ /_prod\z/i
      reasons << "database name '#{db_name}' contains 'production'"              if db_name =~ /production/i

      return if reasons.empty?

      abort(
        "*** SAFETY ABORT ***\n" \
        "Refusing to run anonymization.\n" \
        "Rails.env=#{Rails.env}, ENV_NAME=#{env_name.inspect}, database=#{db_name}\n" \
        "Reasons:\n  - #{reasons.join("\n  - ")}\n" \
        "This task must NOT run against a production database."
      )
    end

    def self.env_name_reasons(env_name)
      if env_name.nil? || env_name.strip.empty?
        ["ENV_NAME is not set - refusing to run without an explicit non-prod environment signal"]
      elsif env_name.strip.casecmp?('prod')
        ["ENV_NAME=#{env_name.inspect} indicates real production"]
      else
        []
      end
    end
    private_class_method :env_name_reasons

    # Runs all anonymization phases in dependency order.
    # Phases 1-5 process people, users, census_members, organizations, and
    # bs_organizations. Phase 6 clears PII fields in families.
    # People must run before census_members so that
    # {#build_person_values_map_for_census} can read already-anonymized values.
    #
    # @return [void]
    def run
      abort_if_production!
      check_idempotency!
      confirm_anonymization!

      log "=== Starting CCA Data Anonymization#{' (DRY RUN)' if @dry_run} ==="
      log "Database: #{db.name}"
      log "Time: #{Time.current}"
      start_time = process_start_time

      # Pre-run: generate HMAC prehashes for records that lack SSN so we can
      # verify name+dob were changed after anonymization. Kept in-memory and
      # passed to the verifier after the run.
      if @dry_run
        log "Skipping prehash generation (dry run)"
        @prehash_map = nil
        @prehash_hmac_key = nil
      else
        @prehash_hmac_key = SecureRandom.hex(32)
        @prehash_run_id = SecureRandom.uuid
        @prehash_map = generate_prehash_map
        persist_prehashes_to_ttl_collection(@prehash_map, @prehash_run_id)
        log "Prehash map: people=#{@prehash_map[:people].size}, census_members=#{@prehash_map[:census_members].size}, organizations=#{@prehash_map[:organizations].size}, bs_organizations=#{@prehash_map[:bs_organizations].size}"
      end

      stats = run_phases
      log_stats(stats, process_end_time_formatted(start_time))

      ensure_protected_users!

      # Post-run: run audit verifier (expensive) and require pass before recording sentinel
      if @dry_run
        log "Skipping verifier (dry run)"
        return
      end

      verifier = DataAnonymizer::Verifier.new(
        mode: :audit,
        prehash_map: @prehash_map,
        hmac_key: @prehash_hmac_key,
        protected_oim_ids: PROTECTED_OIM_IDS
      )
      _results, all_passed, report_path = verifier.run

      unless all_passed
        log "VERIFIER FAILED - report: #{report_path}"
        log "Sentinel will NOT be recorded; investigate and remediate before sharing dumps."
        return
      end

      record_run_sentinel
      log "Re-verification credentials - RUN_ID=#{@prehash_run_id} HMAC_KEY=#{@prehash_hmac_key}"
      log "Store these values to re-run: bundle exec rake data:anonymize:verify RUN_ID=<value> HMAC_KEY=<value>"
      log_admin_access_hint
    end

    private

    # Executes all anonymization phases in dependency order and returns a stats hash.
    #
    # +history_trackers+ is dropped up-front (Phase 0) so that no tracker reads
    # occur against stale PII during the run.
    #
    # @return [Hash{Symbol => Integer}]
    def run_phases
      {
        history_trackers: drop_history_trackers,
        people: anonymize_people,
        users: anonymize_users,
        census_members: anonymize_census_members,
        organizations: anonymize_organizations,
        bs_organizations: anonymize_bs_organizations,
        families: anonymize_families,
        inbox_messages: anonymize_inbox_messages,
        document_identifiers: anonymize_document_identifiers
      }
    end

    # Logs per-phase record counts and total elapsed time.
    def log_stats(stats, elapsed_str)
      log "\n=== Anonymization Complete#{' (DRY RUN - no writes)' if @dry_run} (#{elapsed_str}) ==="
      stats.each { |k, v| log "  #{k}: #{v} records processed" }
    end

    # Prints the admin portal access details so an operator can immediately
    # sign in to the post-anonymization dump and exercise the UI.
    # Only called on a fully successful live run (after verifier PASS and
    # sentinel recorded) so the credentials are shown only when the database
    # is confirmed anonymized and the account is ready.
    # @return [void]
    def log_admin_access_hint
      log "\n==================================================================="
      log "Admin portal access"
      log "  Email    : #{PROTECTED_OIM_IDS.first}"
      log "  Password : #{PROTECTED_USER_PASSWORD}"
      log "  Role     : super_admin"
      log "Sign in and perform a quick spot-check before sharing the dump."
      log "==================================================================="
    end

    # Aborts (or warns in force mode) if this database has already been anonymized.
    #
    # Reads the +data_anonymizer_runs+ sentinel collection. If a prior run is found,
    # cross-checks a small sample of person/user emails against the anonymizer email
    # pattern:
    #
    # - Stale sentinel (data contains real emails): aborts and instructs the operator
    #   to run +rake data:anonymize:reset+ before retrying. This is the expected state
    #   after a DB refresh from a prior environment that left the sentinel intact.
    # - Sentinel matches anonymized data and +force: true+: logs a warning and continues.
    # - Sentinel matches anonymized data and +force: false+: aborts.
    #
    # The sentinel itself is written only after a successful run by {#record_run_sentinel}.
    #
    # @raise [SystemExit] in all cases where a sentinel is found, except force: true
    def check_idempotency!
      runs_collection = db[:data_anonymizer_runs]
      previous = runs_collection.find.sort('completed_at' => -1).limit(1).first
      return unless previous

      msg = "Database '#{db.name}' was already anonymized at #{previous['completed_at']} (run_id: #{previous['_id']})"

      if data_appears_unanonymized?
        abort(
          "ABORT: Stale sentinel detected - #{msg}\n" \
          "A sample of the data still contains real email addresses, indicating the database\n" \
          "was refreshed from a prior environment after the last anonymization run.\n" \
          "Run `rake data:anonymize:reset` to clear the sentinel, then re-run data:anonymize."
        )
      end

      if @force
        log "WARNING: #{msg} - proceeding anyway (FORCE_REANONYMIZE=true)"
      else
        abort("ABORT: #{msg}\nSet FORCE_REANONYMIZE=true to override, or run `rake data:anonymize:reset` after a fresh DB refresh.")
      end
    end

    # Samples a small number of person (and as a fallback, user) email addresses
    # and returns true if any do not match {ANONYMIZED_EMAIL_PATTERN}. Used by
    # {#check_idempotency!} to detect a stale sentinel left behind by a partial
    # DB refresh from a prior environment.
    #
    # @return [Boolean] true when the sample contains a non-anonymizer email
    def data_appears_unanonymized?
      sample = sample_email_addresses
      return false if sample.empty?

      sample.any? { |addr| !addr.match?(ANONYMIZED_EMAIL_PATTERN) }
    end

    # @return [Array<String>] up to {STALE_SENTINEL_SAMPLE_SIZE} non-blank email
    #   addresses pulled from +people+, falling back to +users+ when no person
    #   document carries an email
    def sample_email_addresses
      addresses = sample_person_emails
      addresses = sample_user_emails if addresses.empty?
      addresses
    end

    def sample_person_emails
      return [] unless db.collection_names.include?('people')

      protected_ids = protected_person_ids
      addresses = []

      db[:people].find.projection('emails.address' => 1).limit(STALE_SENTINEL_SAMPLE_SIZE).each do |doc|

        next if protected_ids.include?(doc['_id'])

        Array(doc['emails']).each do |em|
          addr = em['address'].to_s
          addresses << addr if addr.present?
        end
      end

      addresses
    end

    def sample_user_emails
      return [] unless db.collection_names.include?('users')

      protected_ids = protected_user_ids
      addresses = []

      db[:users].find.projection('email' => 1).limit(STALE_SENTINEL_SAMPLE_SIZE).each do |doc|

        next if protected_ids.include?(doc['_id'])

        addr = doc['email'].to_s
        addresses << addr if addr.present?
      end

      addresses
    end

    # Records a sentinel document in +data_anonymizer_runs+ after a successful run.
    # @return [void]
    def record_run_sentinel
      db[:data_anonymizer_runs].insert_one(
        'completed_at' => Time.current,
        'database' => db.name,
        'rails_env' => Rails.env,
        'batch_size' => @batch_size,
        'prehash_run_id' => @prehash_run_id
      )
      log "Sentinel recorded in data_anonymizer_runs (prehash_run_id=#{@prehash_run_id})."
    end

    # Aborts unless every available signal agrees this is a non-prod lower environment.
    # Fail-closed: if ENV_NAME is unset (unknown env), we abort rather than guess.
    #
    # Signals checked:
    #   - ENV_NAME must be set and must NOT equal 'prod' (sourced from mhc_k8s configmaps)
    #   - When Rails.env=production (all deployed envs), ENROLL_REVIEW_ENVIRONMENT must be 'true'
    #   - Mongo database name must not match production patterns (_prod suffix, "production" substring)
    #
    # @raise [SystemExit] if any signal indicates this is, or might be, real production
    def abort_if_production!
      self.class.abort_if_production!
    end

    # Prompts the operator to type YES_ANONYMIZE before proceeding.
    # Skipped when ENV['SKIP_CONFIRMATION'] == 'true' or when in dry-run mode.
    # @raise [SystemExit] if the confirmation phrase is not entered correctly
    def confirm_anonymization!
      return if ENV['SKIP_CONFIRMATION'] == 'true' || @dry_run

      puts "\nWARNING: This will IRREVERSIBLY rewrite all PII in database '#{db.name}'."
      puts "Type YES_ANONYMIZE to proceed:"
      input = $stdin.gets&.strip
      abort("Aborted.") unless input == 'YES_ANONYMIZE'
    end

    # Drops the +history_trackers+ collection, which stores raw PII field values.
    #
    # Mongoid::History records old and new values of tracked fields on every save.
    # Leaving this collection intact after anonymization exposes real names, SSNs,
    # and DOBs in the change history. Dropping the collection is the correct
    # remediation; historical audit data is not needed in a dev/staging dump.
    #
    # @return [Integer] always 0 (collection is dropped, not iterated)
    def drop_history_trackers
      if db.collection_names.include?('history_trackers')
        count = db[:history_trackers].count_documents({})
        if @dry_run
          log "\n--- Phase 0: [DRY RUN] Would drop history_trackers (#{count} documents) ---"
        else
          db[:history_trackers].drop
          log "\n--- Phase 0: Dropped history_trackers (#{count} documents) ---"
        end
      else
        log "\n--- Phase 0: history_trackers collection not present, skipping ---"
      end
      0
    end

    # Anonymizes all documents in the +people+ collection.
    #
    # DOB shifting is consistent within each family group - all family members
    # share the same +shift_days+ value derived by {#build_family_shift_map}.
    # Tribal ID is cleared. Embedded addresses, phones, and emails are replaced.
    # Plain-text +ssn+ fields (legacy) are unset.
    #
    # Person documents linked to a protected user (see {PROTECTED_OIM_IDS}) are
    # skipped so the operator account remains usable post-anonymization.
    #
    # @return [Integer] number of people processed
    def anonymize_people
      collection = db[:people]
      filter = protected_people_filter
      total = collection.count_documents(filter)
      log "\n--- Phase 1: Anonymizing People (#{total}) ---"
      family_shifts = @anonymize_dob ? build_family_shift_map : {}
      # Pre-seed with every ciphertext already in the index so that a retry after
      # a prior aborted run cannot collide with partially-written fake values.
      used_ssns = load_existing_encrypted_ssns(collection)
      processed = 0

      collection.find(filter).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          shift_days = family_shifts[doc['_id']] || AnonymizedData.dob_shift_days
          set_fields = build_person_update(doc, shift_days: shift_days, used_ssns: used_ssns)
          {
            update_one: {
              filter: { '_id' => doc['_id'] },
              update: {
                '$set' => set_fields,
                '$unset' => { 'ssn' => '' }
              }
            }
          }
        end

        if @dry_run
          log "  [DRY RUN] Would update #{updates.size} people in this batch"
        else
          bulk_write_batch(collection, updates)
        end
        processed += batch.size
        log "  #{processed}/#{total} people" if (processed % (batch_size * 5)).zero? || processed >= total
      end
      unless @dry_run
        log "  Clearing embedded version history from people..."
        collection.update_many({}, { '$unset' => { 'versions' => '' } })
      end
      processed
    end

    # Builds the Mongo +$set+ hash for a single person document.
    #
    # @param doc [Hash] raw Mongo person document
    # @param shift_days [Integer] days to shift this person's DOBs (from {#build_family_shift_map})
    # @param used_ssns [Set, nil] set of ciphertexts that must not be reused; should be
    #   pre-seeded from {#load_existing_encrypted_ssns} so that retries after a partial run
    #   cannot collide with values already committed to the index.
    # @return [Hash] Mongo update fields suitable for a +$set+ operation
    def build_person_update(doc, shift_days:, used_ssns: nil)
      new_first = AnonymizedData.first_name
      new_last  = AnonymizedData.last_name
      fields = {
        'first_name' => new_first,
        'last_name' => new_last,
        'full_name' => "#{new_first} #{new_last}",
        'middle_name' => AnonymizedData.first_name.first(1),
        'name_pfx' => nil,
        'name_sfx' => nil,
        'alternate_name' => nil
      }
      if doc['encrypted_ssn'].present?
        enc_ssn = nil
        100.times do
          candidate = AnonymizedData.encrypted_ssn
          unless used_ssns&.include?(candidate)
            enc_ssn = candidate
            break
          end
        end
        raise "Failed to generate a unique encrypted_ssn after 100 attempts" if enc_ssn.nil?

        used_ssns&.add(enc_ssn)
        fields['encrypted_ssn'] = enc_ssn
      end
      fields['tribal_id'] = nil if doc['tribal_id'].present?
      fields.merge!(anonymize_person_dates(doc, shift_days))
      fields.merge!(anonymize_person_embedded(doc))
    end

    # Builds shifted date fields for a person document.
    # @param doc [Hash] raw person document
    # @param shift_days [Integer] days to shift
    # @return [Hash] date fields for +$set+
    def anonymize_person_dates(doc, shift_days)
      fields = {}
      if @anonymize_dob
        fields['dob']           = AnonymizedData.shift_dob(doc['dob'].to_date, shift_days: shift_days)           if doc['dob'].present?
        fields['date_of_death'] = AnonymizedData.shift_dob(doc['date_of_death'].to_date, shift_days: shift_days) if doc['date_of_death'].present?
      end
      fields
    end

    # Anonymizes embedded address, phone, and email arrays in a person document.
    # @param doc [Hash] raw person document
    # @return [Hash] embedded array fields for +$set+
    def anonymize_person_embedded(doc)
      fields = {}
      fields['addresses'] = doc['addresses'].map { |addr| anonymize_address_hash(addr) } if doc['addresses'].present?
      fields['phones']    = doc['phones'].map    { |phone| anonymize_phone_hash(phone) }  if doc['phones'].present?
      fields['emails']    = doc['emails'].map    { |email| anonymize_email_hash(email) }  if doc['emails'].present?
      fields
    end

    # Builds a map of person_id => shift_days by iterating all families.
    #
    # For each family, collects the DOBs of all linked persons and computes a
    # single shift_days value (via {#pick_group_shift_days}) that keeps every
    # person within their age band after shifting. The same shift is applied to
    # all members so relative age gaps are preserved.
    #
    # Persons not in any family receive a random individual shift during Phase 1.
    #
    # @return [Hash{BSON::ObjectId => Integer}] person _id to shift_days mapping
    def build_family_shift_map
      families_collection = db[:families]
      people_collection = db[:people]
      shift_map = {}

      families_collection.find.batch_size(batch_size).each_slice(batch_size) do |family_batch|
        family_person_ids = family_batch.map do |family|
          (family['family_members'] || []).map { |fm| fm['person_id'] }.compact
        end
        all_person_ids = family_person_ids.flatten.uniq
        next if all_person_ids.empty?

        dob_lookup = fetch_dob_lookup(people_collection, all_person_ids)
        apply_family_shifts(shift_map, family_person_ids, dob_lookup)
      end

      log "Built family shift map for #{shift_map.size} people"
      shift_map
    end

    # Queries all non-nil +encrypted_ssn+ values from +collection+ into a +Set+.
    #
    # Called once before the Phase 1 batch loop so that any ciphertext already
    # in the unique index - real data or a fake value written by a prior aborted
    # run - is excluded from the SSN generation candidate pool.
    #
    # @param collection [Mongo::Collection]
    # @return [Set<String>]
    def load_existing_encrypted_ssns(collection)
      ssns = Set.new
      collection
        .find('encrypted_ssn' => { '$exists' => true, '$ne' => nil })
        .projection('encrypted_ssn' => 1, '_id' => 0)
        .each { |doc| ssns.add(doc['encrypted_ssn']) }
      ssns
    end

    # Mongo find filter for {#anonymize_users} that excludes {PROTECTED_OIM_IDS}.
    # @return [Hash]
    def protected_users_filter
      { 'oim_id' => { '$nin' => PROTECTED_OIM_IDS } }
    end

    # Mongo find filter for {#anonymize_people} that excludes any Person linked
    # to a protected User. Returns +{}+ when no protected users exist so the
    # find does not get a no-op +$nin+ clause.
    # @return [Hash]
    def protected_people_filter
      ids = protected_person_ids
      return {} if ids.empty?

      { '_id' => { '$nin' => ids.to_a } }
    end

    # Set of +users._id+ values for accounts whose +oim_id+ is in
    # {PROTECTED_OIM_IDS}. Memoized; safe to call during phase setup because
    # the set is computed before any User mutation occurs.
    # @return [Set<BSON::ObjectId>]
    def protected_user_ids
      @protected_user_ids ||= db[:users]
                              .find('oim_id' => { '$in' => PROTECTED_OIM_IDS })
                              .projection('_id' => 1)
                              .each_with_object(Set.new) { |doc, set| set.add(doc['_id']) }
    end

    # Set of +people._id+ values linked to {#protected_user_ids}. Memoized.
    # @return [Set<BSON::ObjectId>]
    def protected_person_ids
      @protected_person_ids ||= if protected_user_ids.empty?
                                  Set.new
                                else
                                  db[:people]
                                    .find('user_id' => { '$in' => protected_user_ids.to_a })
                                    .projection('_id' => 1)
                                    .each_with_object(Set.new) { |doc, set| set.add(doc['_id']) }
                                end
    end

    # Ensures each {PROTECTED_OIM_IDS} account exists, has a known password,
    # and is granted the +super_admin+ permission so an operator can sign in
    # to the post-anonymization dump and exercise the UI. Called after phases
    # complete and before the verifier so the verifier observes the final
    # state (and skips these records via +protected_oim_ids:+).
    #
    # Idempotent. Uses Mongoid models so Devise password encryption and
    # mongoid-history snapshots fire correctly.
    # @return [void]
    def ensure_protected_users!
      PROTECTED_OIM_IDS.each { |oim_id| ensure_protected_user!(oim_id) }
    end

    def ensure_protected_user!(oim_id)
      if @dry_run
        log "  [DRY RUN] Would ensure protected user '#{oim_id}' has reset password and super_admin role"
        return
      end

      log "\n--- Ensuring protected user '#{oim_id}' ---"
      user = find_or_create_protected_user(oim_id)
      person = find_or_create_protected_person(user)
      grant_super_admin(person, oim_id)
    end

    def find_or_create_protected_user(oim_id)
      user = User.where(oim_id: oim_id).first
      if user
        log "  Resetting password for existing protected user '#{oim_id}' (id=#{user.id})"
        user.update!(
          password: PROTECTED_USER_PASSWORD,
          password_confirmation: PROTECTED_USER_PASSWORD
        )
      else
        log "  Creating protected user '#{oim_id}'"
        user = User.create!(
          email: oim_id,
          oim_id: oim_id,
          roles: ['hbx_staff'],
          password: PROTECTED_USER_PASSWORD,
          password_confirmation: PROTECTED_USER_PASSWORD
        )
      end

      # Clear session tokens via the DB driver to avoid Devise callbacks regenerating them.
      db[:users].update_one(
        { '_id' => user.id },
        { '$set' => { 'current_login_token' => nil, 'authentication_token' => nil } }
      )

      user
    end

    def find_or_create_protected_person(user)
      person = Person.where(user_id: user.id).first
      return person if person

      log "  Creating protected person for user '#{user.oim_id}'"
      Person.create!(first_name: 'system', last_name: 'admin', user: user)
    end

    def grant_super_admin(person, oim_id)
      permission = Permission.super_admin
      if permission.nil?
        log "  WARNING: Permission.super_admin not found; skipping role grant for '#{oim_id}' (run permissions seed)"
        return
      end

      if person.hbx_staff_role&.permission_id == permission.id
        log "  Protected user '#{oim_id}' already has super_admin role"
        return
      end

      person.build_hbx_staff_role(
        permission_id: permission.id,
        subrole: 'super_admin',
        hbx_profile_id: HbxProfile.current_hbx&.id
      )
      person.save!
      log "  Granted super_admin role to protected user '#{oim_id}'"
    end

    def fetch_dob_lookup(people_collection, person_ids)
      lookup = {}
      people_collection.find('_id' => { '$in' => person_ids }).projection('_id' => 1, 'dob' => 1).each do |p|
        lookup[p['_id']] = p['dob']&.to_date
      end
      lookup
    end

    def apply_family_shifts(shift_map, family_person_ids, dob_lookup)
      family_person_ids.each do |person_ids|
        next if person_ids.empty?

        dobs = person_ids.map { |pid| dob_lookup[pid] }.compact
        shift_days = pick_group_shift_days(dobs)
        # Use ||= so a person shared across two families keeps the shift assigned
        # by the first family encountered, preserving DOB alignment within that group.
        person_ids.each { |person_id| shift_map[person_id] ||= shift_days }
      end
    end

    # Picks a single DOB shift (in days) valid for all members of a group.
    #
    # Computes the intersection of allowed shift ranges (via {#allowed_shift_range})
    # across all supplied DOBs. Returns 0 when no common range exists.
    #
    # @param dobs [Array<Date>] dates of birth for all members in the group
    # @return [Integer] shift in days within the +/-30-day policy window, or 0 if ranges do not intersect
    def pick_group_shift_days(dobs)
      return AnonymizedData.dob_shift_days if dobs.empty?

      ranges = dobs.map { |dob| allowed_shift_range(dob, @reference_date) }.compact
      return AnonymizedData.dob_shift_days if ranges.empty?

      min_shift = ranges.map(&:first).max
      max_shift = ranges.map(&:last).min
      return 0 if min_shift.nil? || max_shift.nil?
      return 0 if min_shift > max_shift

      rand(min_shift..max_shift)
    end

    # Computes the permitted DOB shift range for a single person, enforcing:
    # 1. Global bounds: 1920-01-01 minimum, yesterday maximum.
    # 2. Age-band bounds: the shifted DOB must remain in the same band -
    #    under_18 (age < 18), between_18_25 (18 <= age < 26), or over_26 (age >= 26).
    # Shift is bounded to +/-30 days per policy.
    #
    # @param dob [Date] person's date of birth
    # @param reference_date [Date] system date (TimeKeeper.date_of_record)
    # @return [Array(Integer, Integer), nil] [min_shift, max_shift] or nil if no valid range
    def allowed_shift_range(dob, reference_date)
      return nil unless dob.is_a?(Date)

      band = age_band(dob, reference_date)
      min_shift = -30
      max_shift = 30

      # Global bounds
      min_shift = [min_shift, (Date.new(1920, 1, 1) - dob).to_i].max
      max_shift = [max_shift, (reference_date - 1 - dob).to_i].min

      # Band bounds
      cutoff_18 = reference_date - 18.years
      cutoff_26 = reference_date - 26.years

      case band
      when :under_18
        min_shift = [min_shift, (cutoff_18 + 1 - dob).to_i].max
      when :between_18_25
        min_shift = [min_shift, (cutoff_26 + 1 - dob).to_i].max
        max_shift = [max_shift, (cutoff_18 - dob).to_i].min
      when :over_26
        max_shift = [max_shift, (cutoff_26 - dob).to_i].min
      end

      return nil if min_shift > max_shift

      [min_shift, max_shift]
    end

    def age_band(dob, reference_date)
      age = age_on(dob, reference_date)
      return :under_18 if age < 18
      return :between_18_25 if age < 26

      :over_26
    end

    def age_on(dob, reference_date)
      age = reference_date.year - dob.year
      if reference_date.month < dob.month || (reference_date.month == dob.month && reference_date.day < dob.day)
        age - 1
      else
        age
      end
    end

    # Anonymizes all documents in the +users+ collection.
    #
    # Emails are generated as +userN@exampleanonymizer.com+ or +userN@testanonymizer.com+
    # (alternating by sequence number). +oim_id+ is synced to the same anonymized email.
    # The following fields are nulled: authentication_token, current_login_token,
    # identity_verified_date, idp_uuid, identity_response_code,
    # identity_final_decision_code, identity_final_decision_transaction_id,
    # identity_response_description_text.
    #
    # Users whose +oim_id+ is in {PROTECTED_OIM_IDS} are skipped; their credentials
    # are reset by {#ensure_protected_users!} after the phase loop completes.
    #
    # @return [Integer] number of users processed
    def anonymize_users
      collection = db[:users]
      filter = protected_users_filter
      total = collection.count_documents(filter)
      log "\n--- Phase 2: Anonymizing Users (#{total}) ---"
      processed = 0

      collection.find(filter).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.each_with_index.map do |doc, idx|
          seq = processed + idx
          anon_email = AnonymizedData.email(seq)
          {
            update_one: {
              filter: { '_id' => doc['_id'] },
              update: {
                '$set' => {
                  'email' => anon_email,
                  'oim_id' => anon_email,
                  'authentication_token' => nil,
                  'current_login_token' => nil,
                  'identity_verified_date' => nil,
                  'idp_uuid' => nil,
                  'identity_response_code' => nil,
                  'identity_final_decision_code' => nil,
                  'identity_final_decision_transaction_id' => nil,
                  'identity_response_description_text' => nil
                }
              }
            }
          }
        end

        if @dry_run
          log "  [DRY RUN] Would update #{updates.size} users in this batch"
        else
          bulk_write_batch(collection, updates)
        end
        processed += batch.size
        log "  #{processed}/#{total} users" if (processed % (batch_size * 5)).zero? || processed >= total
      end
      processed
    end

    # Anonymizes all documents in the +census_members+ collection.
    #
    # For main-app +CensusEmployee+ documents that carry an +employee_role_id+,
    # the already-anonymized Person values (name, DOB, SSN) written in Phase 1
    # are copied directly from the people collection via
    # {#build_person_values_map_for_census}. This ensures that the same individual
    # has identical fake identifiers in both +people+ and +census_members+.
    #
    # For +BenefitSponsors::CensusMembers::CensusEmployee+ documents (no
    # +employee_role_id+), fresh fake values are generated independently.
    #
    # Embedded +census_dependents+ receive the same DOB shift as their parent
    # employee so that age gaps within a family group are preserved.
    #
    # @note CCA Individual Market is disabled. +consumer_role+, +resident_role+,
    #   and VLP documents are not present for census members and are not processed.
    # @note +dba+, +fein+, and +npn+ are never touched by this phase.
    # @return [Integer] number of census member documents processed
    def anonymize_census_members
      collection = db[:census_members]
      total = collection.count_documents({})
      log "\n--- Phase 3: Anonymizing Census Members (#{total}) ---"
      person_sync_map = build_person_values_map_for_census
      processed = 0

      collection.find.batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          employee_role_id = doc['employee_role_id']
          person_vals = employee_role_id ? person_sync_map[employee_role_id] : nil

          shift_days = census_member_shift_days(doc, person_vals)
          set_fields = build_census_member_update(doc, shift_days: shift_days, person_vals: person_vals)

          if doc['census_dependents'].present?
            set_fields['census_dependents'] = doc['census_dependents'].map do |dep|
              anonymize_census_dependent_hash(dep, shift_days: shift_days)
            end
          end

          {
            update_one: {
              filter: { '_id' => doc['_id'] },
              update: {
                '$set' => set_fields,
                '$unset' => { 'ssn' => '' }
              }
            }
          }
        end

        if @dry_run
          log "  [DRY RUN] Would update #{updates.size} census members in this batch"
        else
          bulk_write_batch(collection, updates)
        end
        processed += batch.size
        log "  #{processed}/#{total} census members" if (processed % (batch_size * 5)).zero? || processed >= total
      end
      processed
    end

    # Computes the DOB shift in days to apply to a census member and its dependents.
    #
    # When linked to an already-anonymized Person, derives the shift from the delta
    # between the Person's (now fake) DOB and the census member's original DOB.
    # When no Person link exists, picks a group-consistent shift from all member DOBs.
    #
    # @param doc [Hash] raw census member document
    # @param person_vals [Hash, nil] anonymized person values from {#build_person_values_map_for_census}
    # @return [Integer] shift in days
    def census_member_shift_days(doc, person_vals)
      if person_vals && person_vals['dob'].present? && doc['dob'].present?
        (person_vals['dob'].to_date - doc['dob'].to_date).to_i
      elsif person_vals
        0
      else
        dep_dobs = (doc['census_dependents'] || []).map { |dep| dep['dob']&.to_date }.compact
        all_dobs = [doc['dob']&.to_date].compact + dep_dobs
        pick_group_shift_days(all_dobs)
      end
    end

    # Builds a map of employee_role_id => anonymized person values for census sync.
    #
    # Runs after Phase 1 has already written fake data to the people collection.
    # Queries all people that have embedded employee_roles and indexes their
    # anonymized first_name, last_name, dob, and encrypted_ssn by each
    # employee_role._id (which is what CensusEmployee.employee_role_id points to).
    #
    # Only main-app CensusEmployee documents carry employee_role_id.
    # BenefitSponsors::CensusMembers::CensusEmployee documents do not have this
    # field and will receive independently generated fake values.
    #
    # @return [Hash{BSON::ObjectId => Hash}] map from employee_role ObjectId
    #   to a hash with keys first_name, last_name, dob, encrypted_ssn
    def build_person_values_map_for_census
      map = {}
      db[:people].find(
        'employee_roles' => { '$exists' => true, '$ne' => [] }
      ).projection(
        'first_name' => 1,
        'last_name' => 1,
        'dob' => 1,
        'encrypted_ssn' => 1,
        'employee_roles._id' => 1
      ).each do |person|
        vals = {
          'first_name' => person['first_name'],
          'last_name' => person['last_name'],
          'dob' => person['dob'],
          'encrypted_ssn' => person['encrypted_ssn']
        }
        (person['employee_roles'] || []).each do |er|
          map[er['_id']] = vals
        end
      end
      log "  Built person-census sync map for #{map.size} employee roles"
      map
    end

    # Builds the Mongo +$set+ hash for a single census member document.
    #
    # When +person_vals+ is provided, the linked Person's already-anonymized
    # first_name, last_name, dob, and encrypted_ssn are used directly to ensure
    # consistency between the +people+ and +census_members+ collections.
    # When +person_vals+ is nil (no Person link), fresh fake values are generated.
    #
    # @param doc [Hash] raw Mongo census member document
    # @param shift_days [Integer] DOB shift in days; used only when +person_vals+ is nil
    # @param person_vals [Hash, nil] anonymized person fields from {#build_person_values_map_for_census}
    # @return [Hash] Mongo update fields suitable for a +$set+ operation
    def build_census_member_update(doc, shift_days:, person_vals: nil)
      fields = if person_vals
                 build_census_member_fields_from_person(doc, person_vals)
               else
                 build_census_member_fields_random(doc, shift_days)
               end

      fields['address'] = anonymize_address_hash(doc['address']) if doc['address'].present?
      fields['email']   = anonymize_email_hash(doc['email'])     if doc['email'].present?
      fields
    end

    def build_census_member_fields_from_person(doc, person_vals)
      fields = {
        'first_name' => person_vals['first_name'],
        'last_name' => person_vals['last_name'],
        'middle_name' => nil,
        'name_sfx' => nil
      }
      fields['encrypted_ssn'] = person_vals['encrypted_ssn'] if doc['encrypted_ssn'].present? && person_vals['encrypted_ssn'].present?
      fields['dob']           = person_vals['dob']           if @anonymize_dob && doc['dob'].present? && person_vals['dob'].present?
      fields
    end

    def build_census_member_fields_random(doc, shift_days)
      fields = {
        'first_name' => AnonymizedData.first_name,
        'last_name' => AnonymizedData.last_name,
        'middle_name' => nil,
        'name_sfx' => nil
      }
      fields['encrypted_ssn'] = AnonymizedData.encrypted_ssn if doc['encrypted_ssn'].present?
      fields['dob'] = AnonymizedData.shift_dob(doc['dob'].to_date, shift_days: shift_days) if @anonymize_dob && doc['dob'].present?
      fields
    end

    # Anonymizes a single census_dependent embedded hash.
    #
    # @param dep [Hash] raw census_dependent sub-document
    # @param shift_days [Integer] DOB shift in days (same value as the parent employee)
    # @return [Hash] anonymized copy of the dependent hash
    def anonymize_census_dependent_hash(dep, shift_days:)
      dep = dep.dup
      dep['first_name'] = AnonymizedData.first_name
      dep['last_name'] = AnonymizedData.last_name
      dep['middle_name'] = nil
      dep['name_sfx'] = nil
      dep['encrypted_ssn'] = AnonymizedData.encrypted_ssn if dep['encrypted_ssn'].present?
      dep['dob'] = AnonymizedData.shift_dob(dep['dob'].to_date, shift_days: shift_days) if @anonymize_dob && dep['dob'].present?
      dep['address'] = anonymize_address_hash(dep['address']) if dep['address'].present?
      dep['email']   = anonymize_email_hash(dep['email'])     if dep['email'].present?
      dep
    end

    # Anonymizes all documents in the legacy +organizations+ collection.
    #
    # Replaces: legal_name, broker_agency_profile ACH fields (ach_routing_number,
    # ach_account_number), and office location addresses and phones.
    #
    # @note +dba+, +fein+, and +npn+ are intentionally NOT anonymized.
    # @return [Integer] number of organization documents processed
    def anonymize_organizations
      collection = db[:organizations]
      total = collection.count_documents({})
      log "\n--- Phase 4: Anonymizing Organizations (#{total}) ---"
      processed = 0

      collection.find.batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => build_org_update(doc) } } }
        end

        if @dry_run
          log "  [DRY RUN] Would update #{updates.size} organizations in this batch"
        else
          bulk_write_batch(collection, updates)
        end
        processed += batch.size
        log "  #{processed}/#{total} organizations" if (processed % (batch_size * 5)).zero? || processed >= total
      end
      unless @dry_run
        log "  Clearing embedded version history from organizations..."
        collection.update_many({}, { '$unset' => { 'versions' => '' } })
      end
      processed
    end

    # Builds the +$set+ hash for a single legacy organization document.
    # Anonymizes legal_name, broker ACH fields, and office location addresses/phones.
    # @param doc [Hash] raw organization document
    # @return [Hash] fields for +$set+
    def build_org_update(doc)
      set_fields = { 'legal_name' => AnonymizedData.company_name }

      if doc['broker_agency_profile'].present?
        bap = doc['broker_agency_profile'].dup
        if bap['ach_routing_number'].present?
          fake_rn = AnonymizedData.routing_number
          bap['ach_routing_number']              = fake_rn
          bap['ach_routing_number_confirmation'] = fake_rn
        end
        bap['ach_account_number'] = AnonymizedData.account_number if bap['ach_account_number'].present?
        set_fields['broker_agency_profile'] = bap
      end

      set_fields['office_locations'] = anonymize_office_locations(doc['office_locations']) if doc['office_locations'].present?
      set_fields
    end

    # Replaces addresses and phones in an array of office_location sub-documents.
    # @param locations [Array<Hash>] raw office_locations array
    # @return [Array<Hash>] anonymized copies
    def anonymize_office_locations(locations)
      locations.map do |ol|
        ol = ol.dup
        ol['address'] = anonymize_address_hash(ol['address']) if ol['address'].present?
        ol['phone']   = anonymize_phone_hash(ol['phone'])     if ol['phone'].present?
        ol
      end
    end

    # Anonymizes all documents in the +benefit_sponsors_organizations_organizations+ collection.
    #
    # Replaces: legal_name (broker/employer orgs only), and for each embedded profile: ACH fields
    # (ach_routing_number, ach_account_number) and office location addresses and phones.
    #
    # Issuer profile organizations (+BenefitSponsors::Organizations::IssuerProfile+) are excluded
    # from +legal_name+ anonymization because downstream code (e.g. +carrier_logo+) relies on
    # the real carrier name to resolve logo assets.
    #
    # @note +dba+, +fein+, and +npn+ are intentionally NOT anonymized.
    # @return [Integer] number of BS organization documents processed
    def anonymize_bs_organizations
      collection = db[:benefit_sponsors_organizations_organizations]
      total = collection.count_documents({})
      return 0 if total.zero?

      log "\n--- Phase 5: Anonymizing BS Organizations (#{total}) ---"
      processed = 0

      collection.find.batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => build_bs_org_update(doc) } } }
        end

        if @dry_run
          log "  [DRY RUN] Would update #{updates.size} BS organizations in this batch"
        else
          bulk_write_batch(collection, updates)
        end
        processed += batch.size
        log "  #{processed}/#{total} BS organizations" if (processed % (batch_size * 5)).zero? || processed >= total
      end
      processed
    end

    # Builds the +$set+ hash for a single BS organization document.
    #
    # Issuer profile organizations are detected by checking the embedded +profiles+ array for
    # +_type == 'BenefitSponsors::Organizations::IssuerProfile'+. Their +legal_name+ is preserved
    # because downstream code (e.g. +carrier_logo+) resolves logo assets by carrier name.
    # Non-issuer organizations (employers, broker agencies) have +legal_name+ replaced.
    #
    # @param doc [Hash] raw BS organization document
    # @return [Hash] fields for +$set+
    def build_bs_org_update(doc)
      issuer_org = doc['profiles']&.any? { |p| p['_type'] == 'BenefitSponsors::Organizations::IssuerProfile' }
      set_fields = issuer_org ? {} : { 'legal_name' => AnonymizedData.company_name }
      set_fields['profiles'] = doc['profiles'].map { |p| anonymize_bs_profile(p) } if doc['profiles'].present?
      set_fields
    end

    # Anonymizes a single BenefitSponsors organization profile sub-document.
    # Replaces ACH fields, office location addresses/phones, and employer
    # attestation document filenames (which can embed numeric document IDs).
    # @param profile [Hash] raw profile sub-document
    # @return [Hash] anonymized copy
    def anonymize_bs_profile(profile)
      profile = profile.dup
      if profile['ach_routing_number'].present?
        fake_rn = AnonymizedData.routing_number
        profile['ach_routing_number']              = fake_rn
        profile['ach_routing_number_confirmation'] = fake_rn
      end
      profile['ach_account_number']  = AnonymizedData.account_number if profile['ach_account_number'].present?
      profile['office_locations']    = anonymize_office_locations(profile['office_locations']) if profile['office_locations'].present?
      profile['employer_attestation'] = anonymize_employer_attestation(profile['employer_attestation']) if profile['employer_attestation'].present?
      profile
    end

    # Replaces sensitive fields on each employer attestation document with safe
    # placeholders. Specifically:
    #   - +title+ / +subject+: original filenames may embed numeric document IDs
    #     that look like 9-digit SSNs to the streaming regex scanner.
    #   - +identifier+: a URN that encodes the real S3 bucket name and document UUID;
    #     the bucket name reveals internal infrastructure and the UUID can be used
    #     to retrieve the original file if S3 credentials are available.
    # @param attestation [Hash] raw employer_attestation sub-document
    # @return [Hash] anonymized copy
    def anonymize_employer_attestation(attestation)
      attestation = attestation.dup
      docs = attestation['employer_attestation_documents']
      return attestation unless docs.present?

      attestation['employer_attestation_documents'] = docs.each_with_index.map do |doc, idx|
        doc = doc.dup
        ext = File.extname(doc['title'].to_s).presence || '.pdf'
        doc['title']   = "document_#{idx + 1}#{ext}"
        doc['subject'] = "document_#{idx + 1}#{ext}"
        doc['identifier'] = "urn:openhbx:terms:v1:file_storage:s3:bucket:anonymized##{SecureRandom.uuid}" if doc['identifier'].present?
        doc
      end
      attestation
    end

    # Clears the +e_case_id+ field on all family documents.
    #
    # +e_case_id+ is a foreign key to an external eligibility case management system.
    # Leaving it intact in a shared dump creates a linkage vector: anyone with
    # access to both the eligibility system and the dump can re-identify a family.
    # We clear it by +$unset+ rather than setting nil so the field is removed entirely.
    #
    # @return [Integer] number of families processed
    def anonymize_families
      collection = db[:families]
      total = collection.count_documents('e_case_id' => { '$exists' => true, '$ne' => nil })
      log "\n--- Phase 6: Anonymizing Families (#{total} with e_case_id) ---"
      return 0 if total.zero?

      if @dry_run
        log "  [DRY RUN] Would unset e_case_id on #{total} family documents"
      else
        collection.update_many(
          { 'e_case_id' => { '$exists' => true, '$ne' => nil } },
          { '$unset' => { 'e_case_id' => '' } }
        )
        log "  Cleared e_case_id on #{total} families"
      end
      total
    end

    def anonymize_inbox_messages
      log "\n--- Phase 7: Anonymizing Inbox Message Bodies ---"
      total  = redact_inbox_messages_at_path(db[:people], 'inbox')
      total += redact_inbox_messages_at_path(db[:organizations], 'employer_profile.inbox')
      total += redact_inbox_messages_at_path(db[:organizations], 'broker_agency_profile.inbox')
      total += redact_inbox_messages_at_path(db[:organizations], 'hbx_profile.inbox')
      total += redact_bs_org_inbox_messages
      log "  Phase 7 complete: #{total} documents processed" if total.positive?
      total
    end

    def redact_inbox_messages_at_path(collection, inbox_path)
      messages_path = "#{inbox_path}.messages"
      filter        = { "#{messages_path}.0" => { '$exists' => true } }
      total         = collection.count_documents(filter)
      return 0 if total.zero?

      log "  #{collection.name}: #{total} documents with inbox messages"
      path_keys = inbox_path.split('.')
      processed = 0

      collection.find(filter).projection(inbox_path => 1).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.filter_map { |doc| inbox_message_update(doc, path_keys, messages_path) }

        if @dry_run
          log "  [DRY RUN] Would redact document names in #{batch.size} #{collection.name} inbox messages"
        else
          bulk_write_batch(collection, updates) unless updates.empty?
        end
        processed += batch.size
      end
      processed
    end

    def inbox_message_update(doc, path_keys, messages_path)
      inbox    = path_keys.reduce(doc) { |d, k| d.is_a?(Hash) ? d[k] : nil }
      messages = inbox.is_a?(Hash) ? inbox['messages'] : nil
      return nil unless messages.is_a?(Array) && messages.present?

      redacted = messages.map { |msg| redact_message_fields(msg) }
      { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => { messages_path => redacted } } } }
    end

    def redact_bs_org_inbox_messages
      collection = db[:benefit_sponsors_organizations_organizations]
      filter     = { 'profiles.inbox.messages.0' => { '$exists' => true } }
      total      = collection.count_documents(filter)
      return 0 if total.zero?

      log "  #{collection.name}: #{total} documents with inbox messages"
      processed = 0

      collection.find(filter).projection('profiles' => 1).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.filter_map { |doc| bs_org_inbox_message_update(doc) }

        if @dry_run
          log "  [DRY RUN] Would redact document names in #{batch.size} BS org inbox messages"
        else
          bulk_write_batch(collection, updates) unless updates.empty?
        end
        processed += batch.size
      end
      processed
    end

    def bs_org_inbox_message_update(doc)
      profiles = doc['profiles']
      return nil unless profiles.is_a?(Array)

      updated = profiles.map { |p| redact_profile_inbox(p) }
      { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => { 'profiles' => updated } } } }
    end

    def redact_profile_inbox(profile)
      messages = profile.dig('inbox', 'messages')
      return profile unless messages.is_a?(Array) && messages.present?

      profile                      = profile.dup
      profile['inbox']             = profile['inbox'].dup
      profile['inbox']['messages'] = messages.map { |msg| redact_message_fields(msg) }
      profile
    end

    def redact_message_fields(msg)
      return msg unless msg.is_a?(Hash)

      msg = msg.dup
      msg['body'] = redact_document_filename(msg['body']) if msg['body'].present?
      msg['from'] = AnonymizedData.company_name if msg['from'].present?
      msg
    end

    def redact_document_filename(body)
      return body if body.blank?

      body = body.gsub(/filename=[^&"'\s]+/, 'filename=document-redacted')
      body.gsub(%r{target=['"]_blank['"]>\s*[^<]+\s*</a>}i, "target='_blank'>[document-redacted]</a>")
    end

    def anonymize_document_identifiers
      log "\n--- Phase 8: Anonymizing Document S3 References ---"
      total  = redact_document_identifiers_at_path(db[:people], 'documents')
      total += redact_document_identifiers_at_path(db[:organizations], 'documents')
      total += redact_document_identifiers_at_path(db[:organizations], 'employer_profile.documents')
      total += redact_document_identifiers_at_path(db[:organizations], 'broker_agency_profile.documents')
      total += redact_bs_document_identifiers
      log "  Phase 8 complete: #{total} documents processed" if total.positive?
      total
    end

    def redact_document_identifiers_at_path(collection, docs_path)
      filter = { "#{docs_path}.0" => { '$exists' => true } }
      total  = collection.count_documents(filter)
      return 0 if total.zero?

      log "  #{collection.name}: #{total} records with embedded documents"
      path_keys = docs_path.split('.')
      processed = 0

      collection.find(filter).projection(docs_path => 1).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.filter_map { |doc| document_identifier_update(doc, path_keys, docs_path) }

        if @dry_run
          log "  [DRY RUN] Would redact S3 identifiers in #{batch.size} #{collection.name} records"
        else
          bulk_write_batch(collection, updates) unless updates.empty?
        end
        processed += batch.size
      end
      processed
    end

    def document_identifier_update(doc, path_keys, docs_path)
      documents = path_keys.reduce(doc) { |d, k| d.is_a?(Hash) ? d[k] : nil }
      return nil unless documents.is_a?(Array) && documents.present?

      redacted = documents.each_with_index.map { |d, idx| redact_document_identifier_field(d, idx) }
      { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => { docs_path => redacted } } } }
    end

    def redact_document_identifier_field(document, idx)
      return document unless document.is_a?(Hash)
      return document if document['identifier'].blank? && document['title'].blank? && document['subject'].blank?

      document = document.dup
      ext = File.extname(document['title'].to_s).presence || '.pdf'
      document['title']      = "document_#{idx + 1}#{ext}" if document['title'].present?
      document['subject']    = "document_#{idx + 1}#{ext}" if document['subject'].present?
      document['identifier'] = anonymized_document_identifier if document['identifier'].present?
      document
    end

    def redact_bs_document_identifiers
      collection = db[:benefit_sponsors_documents_documents]
      return 0 unless db.collection_names.include?(collection.name)

      filter = {
        'identifier' => { '$exists' => true, '$nin' => [nil, '', 'missing_uri'] },
        'documentable_type' => { '$ne' => 'BenefitSponsors::Organizations::IssuerProfile' }
      }
      total = collection.count_documents(filter)
      return 0 if total.zero?

      log "  #{collection.name}: #{total} documents with S3 identifiers"
      processed = 0

      collection.find(filter).projection('_id' => 1).batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          { update_one: { filter: { '_id' => doc['_id'] }, update: { '$set' => { 'identifier' => anonymized_document_identifier } } } }
        end

        if @dry_run
          log "  [DRY RUN] Would redact S3 identifiers in #{batch.size} BS documents"
        else
          bulk_write_batch(collection, updates) unless updates.empty?
        end
        processed += batch.size
      end
      processed
    end

    def anonymized_document_identifier
      "urn:openhbx:terms:v1:file_storage:s3:bucket:anonymized##{SecureRandom.uuid}"
    end

    # Replaces address PII fields in an embedded address hash.
    #
    # ZIP and county are preserved by default to avoid impacting premium/rating
    # calculations. Pass +anonymize_zip: true+ or +anonymize_county: true+ to
    # the Runner constructor (or use ENV flags in the rake task) to override.
    #
    # @param addr [Hash, nil] embedded address sub-document
    # @return [Hash, nil] anonymized copy, or nil if input is nil
    def anonymize_address_hash(addr)
      return addr if addr.nil?

      addr = addr.dup
      addr['address_1'] = AnonymizedData.address_1
      addr['address_2'] = nil
      addr['address_3'] = nil if addr.key?('address_3')
      addr['city'] = AnonymizedData.city
      if addr.key?('state') && @anonymize_state
        original_state = addr['state']
        new_state = AnonymizedData.state
        attempts = 0
        # Try a few times to avoid returning the same state by chance
        while new_state == original_state && attempts < 10
          new_state = AnonymizedData.state
          attempts += 1
        end
        addr['state'] = new_state
      end
      addr['zip']    = AnonymizedData.zip    if @anonymize_zip
      addr['county'] = AnonymizedData.county if addr.key?('county') && @anonymize_county
      addr
    end

    # Replaces phone PII fields in an embedded phone hash.
    # Preserves structural fields (kind, primary, country_code, etc.).
    # @param phone [Hash, nil] embedded phone sub-document
    # @return [Hash, nil] anonymized copy, or nil if input is nil
    def anonymize_phone_hash(phone)
      return phone if phone.nil?

      phone = phone.dup
      phone['area_code'] = AnonymizedData.area_code
      phone['number'] = AnonymizedData.phone_number
      phone['full_phone_number'] = "#{phone['area_code']}#{phone['number']}"
      phone['extension'] = nil
      phone
    end

    # Replaces the email address in an embedded email hash.
    # Preserves structural fields (kind, etc.).
    # @param email_hash [Hash, nil] embedded email sub-document
    # @return [Hash, nil] anonymized copy, or nil if input is nil
    def anonymize_email_hash(email_hash)
      return email_hash if email_hash.nil?

      email_hash = email_hash.dup
      email_hash['address'] = AnonymizedData.email
      email_hash
    end

    # Build a prehash map of canonical HMACs for records that should be
    # deterministically proven changed. Excludes DOB per policy decision.
    # Returns a hash with keys :people, :census_members, :organizations, :bs_organizations
    # where each value is a map of id_str => hmac.
    def generate_prehash_map
      map = { people: {}, census_members: {}, organizations: {}, bs_organizations: {} }
      generate_prehash_for_people(map)
      generate_prehash_for_census_members(map)
      generate_prehash_for_organizations(map)
      generate_prehash_for_bs_organizations(map)
      map
    end

    def generate_prehash_for_people(map)
      no_ssn_filter = { '$or' => [{ 'ssn' => { '$exists' => false } }, { 'ssn' => nil }, { 'ssn' => '' }] }
      cursor = db[:people].find(no_ssn_filter).projection('first_name' => 1, 'last_name' => 1, 'addresses' => 1, 'phones' => 1)
      cursor.batch_size(batch_size).each do |p|
        next if p['first_name'].to_s.strip.empty? || p['last_name'].to_s.strip.empty?
        next if protected_person_ids.include?(p['_id'])

        map[:people][p['_id'].to_s] = OpenSSL::HMAC.hexdigest('SHA256', @prehash_hmac_key, canonical_person_payload(p))
      end
    end

    def generate_prehash_for_census_members(map)
      no_ssn_filter = { '$or' => [{ 'ssn' => { '$exists' => false } }, { 'ssn' => nil }, { 'ssn' => '' }] }
      cursor = db[:census_members].find(no_ssn_filter).projection('first_name' => 1, 'last_name' => 1, 'address' => 1, 'phone' => 1)
      cursor.batch_size(batch_size).each do |c|
        next if c['first_name'].to_s.strip.empty? || c['last_name'].to_s.strip.empty?

        map[:census_members][c['_id'].to_s] = OpenSSL::HMAC.hexdigest('SHA256', @prehash_hmac_key, canonical_census_payload(c))
      end
    end

    def generate_prehash_for_organizations(map)
      cursor = db[:organizations].find.projection('legal_name' => 1, 'broker_agency_profile' => 1)
      cursor.batch_size(batch_size).each do |o|
        next if o['legal_name'].to_s.strip.empty?

        map[:organizations][o['_id'].to_s] = OpenSSL::HMAC.hexdigest('SHA256', @prehash_hmac_key, canonical_org_payload(o))
      end
    end

    def generate_prehash_for_bs_organizations(map)
      cursor = db[:benefit_sponsors_organizations_organizations].find.projection('legal_name' => 1, 'profiles' => 1)
      cursor.batch_size(batch_size).each do |b|
        next if b['legal_name'].to_s.strip.empty?

        map[:bs_organizations][b['_id'].to_s] = OpenSSL::HMAC.hexdigest('SHA256', @prehash_hmac_key, canonical_bs_org_payload(b))
      end
    end

    # Persist prehash digests to a temporary TTL collection for crash tolerance.
    # Documents expire after 7 days.
    def persist_prehashes_to_ttl_collection(map, run_id)
      col = db[:data_anonymizer_prehashes]
      # ensure TTL index exists
      begin
        col.indexes.create_one({ created_at: 1 }, expire_after_seconds: 7 * 24 * 3600)
      rescue Mongo::Error => e
        log "TTL index on data_anonymizer_prehashes already exists or failed to create: #{e.message}"
      end

      inserts = []
      map.each do |collection_sym, id_map|
        collection_name = collection_sym.to_s
        id_map.each do |id_str, digest|
          rec_id = begin
            BSON::ObjectId.from_string(id_str)
          rescue StandardError
            id_str
          end
          inserts << {
            'run_id' => run_id,
            'collection' => collection_name,
            'record_id' => rec_id,
            'scope' => 'canonical_prehash',
            'digest' => digest,
            'created_at' => Time.current
          }
        end
      end

      col.insert_many(inserts) unless inserts.empty?
      log "Persisted #{inserts.size} prehash digests to data_anonymizer_prehashes (TTL 7d, run_id=#{run_id})."
    end

    # Executes a bulk write and re-raises any +BulkWriteError+ after logging context.
    # Fails loudly so partial anonymization is never silently accepted.
    # @param collection [Mongo::Collection]
    # @param updates [Array<Hash>] bulk write operations
    # @return [Mongo::BulkWriteResult, nil]
    def bulk_write_batch(collection, updates)
      return if updates.empty?

      collection.bulk_write(updates, ordered: false)
    rescue Mongo::Error::BulkWriteError => e
      log "  ERROR: Bulk write failed: #{e.message}"
      raise
    end

    def log(msg)
      puts msg unless Rails.env.test?
      Rails.logger.info("[DataAnonymizer] #{msg}")
    end
  end
  # rubocop:enable Metrics/ClassLength
end
