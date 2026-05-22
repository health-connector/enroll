# frozen_string_literal: true

require_relative 'anonymized_data'
require_relative 'canonical_payloads'
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

    attr_reader :batch_size, :client, :db

    # @param batch_size [Integer] documents per bulk_write batch (default 1000).
    #   Larger values improve throughput at the cost of memory.
    # @param dry_run [Boolean] when true, logs actions without writing to the database.
    # @param force [Boolean] when true, skips the idempotency guard and re-anonymizes.
    # @param anonymize_zip [Boolean] opt in to anonymize zip; preserved by default to protect rating calculations.
    # @param anonymize_county [Boolean] opt in to anonymize county; preserved by default to protect rating calculations.
    # @param anonymize_dob [Boolean] opt in to shift DOB ±30 days; preserved by default to protect age-band eligibility.
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
      start_time = Time.current

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
      log_stats(stats, (Time.current - start_time).round(1))

      # Post-run: run audit verifier (expensive) and require pass before recording sentinel
      if @dry_run
        log "Skipping verifier (dry run)"
        return
      end

      verifier = DataAnonymizer::Verifier.new(mode: :audit, prehash_map: @prehash_map, hmac_key: @prehash_hmac_key)
      _results, all_passed, report_path = verifier.run

      unless all_passed
        log "VERIFIER FAILED — report: #{report_path}"
        log "Sentinel will NOT be recorded; investigate and remediate before sharing dumps."
        return
      end

      record_run_sentinel
      log "Re-verification credentials — RUN_ID=#{@prehash_run_id} HMAC_KEY=#{@prehash_hmac_key}"
      log "Store these values to re-run: bundle exec rake data:anonymize:verify RUN_ID=<value> HMAC_KEY=<value>"
    end

    private

    # Executes all anonymization phases in dependency order and returns a stats hash.
    # @return [Hash{Symbol => Integer}]
    def run_phases
      {
        history_trackers: drop_history_trackers,
        people: anonymize_people,
        users: anonymize_users,
        census_members: anonymize_census_members,
        organizations: anonymize_organizations,
        bs_organizations: anonymize_bs_organizations,
        families: anonymize_families
      }
    end

    # Logs the per-phase record counts and total elapsed time.
    # @param stats [Hash{Symbol => Integer}]
    # @param elapsed [Float] total run time in seconds
    # @return [void]
    def log_stats(stats, elapsed)
      log "\n=== Anonymization Complete#{' (DRY RUN — no writes)' if @dry_run} (#{elapsed}s) ==="
      stats.each { |k, v| log "  #{k}: #{v} records processed" }
    end

    # Aborts (or warns in force mode) if this database has already been anonymized.
    #
    # Reads the +data_anonymizer_runs+ sentinel collection. If a prior run is found,
    # aborts unless +force: true+, in which case a warning is logged and the run continues.
    # The sentinel itself is written only after a successful run by {#record_run_sentinel}.
    #
    # @raise [SystemExit] if already anonymized and force is false
    def check_idempotency!
      runs_collection = db[:data_anonymizer_runs]
      previous = runs_collection.find.sort('completed_at' => -1).limit(1).first
      return unless previous

      msg = "Database '#{db.name}' was already anonymized at #{previous['completed_at']} (run_id: #{previous['_id']})"
      if @force
        log "WARNING: #{msg} — proceeding anyway (FORCE_REANONYMIZE=true)"
      else
        abort("ABORT: #{msg}\nSet FORCE_REANONYMIZE=true to override.")
      end
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
      env_name = ENV.fetch('ENV_NAME', nil)
      enroll_review_env = ENV.fetch('ENROLL_REVIEW_ENVIRONMENT', nil)
      reasons = []

      if env_name.nil? || env_name.strip.empty?
        reasons << "ENV_NAME is not set — refusing to run without an explicit non-prod environment signal"
      elsif env_name == 'prod'
        reasons << "ENV_NAME='prod' indicates real production"
      end

      reasons << "Rails.env=production and ENROLL_REVIEW_ENVIRONMENT=#{enroll_review_env.inspect} (expected 'true' in lower envs)" if Rails.env.production? && enroll_review_env != 'true'

      reasons << "database name '#{db.name}' ends in _prod (production pattern)" if db.name =~ /_prod\z/i
      reasons << "database name '#{db.name}' contains 'production'"              if db.name =~ /production/i

      return if reasons.empty?

      abort(
        "*** SAFETY ABORT ***\n" \
        "Refusing to run anonymization.\n" \
        "Rails.env=#{Rails.env}, ENV_NAME=#{env_name.inspect}, database=#{db.name}\n" \
        "Reasons:\n  - #{reasons.join("\n  - ")}\n" \
        "This task must NOT run against a production database."
      )
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
    # DOB shifting is consistent within each family group — all family members
    # share the same +shift_days+ value derived by {#build_family_shift_map}.
    # Tribal ID is cleared. Embedded addresses, phones, and emails are replaced.
    # Plain-text +ssn+ fields (legacy) are unset.
    #
    # @return [Integer] number of people processed
    def anonymize_people
      collection = db[:people]
      total = collection.count_documents({})
      log "\n--- Phase 1: Anonymizing People (#{total}) ---"
      family_shifts = build_family_shift_map
      processed = 0

      collection.find.batch_size(batch_size).each_slice(batch_size) do |batch|
        updates = batch.map do |doc|
          shift_days = family_shifts[doc['_id']] || AnonymizedData.dob_shift_days
          set_fields = build_person_update(doc, shift_days: shift_days)
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
      processed
    end

    # Builds the Mongo +$set+ hash for a single person document.
    #
    # @param doc [Hash] raw Mongo person document
    # @param shift_days [Integer] days to shift this person's DOBs (from {#build_family_shift_map})
    # @return [Hash] Mongo update fields suitable for a +$set+ operation
    def build_person_update(doc, shift_days:)
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
      fields['encrypted_ssn'] = AnonymizedData.encrypted_ssn if doc['encrypted_ssn'].present?
      fields['tribal_id']     = nil                    if doc['tribal_id'].present?
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
    # @return [Integer] shift in days within the ±30-day policy window, or 0 if ranges do not intersect
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
    # 2. Age-band bounds: the shifted DOB must remain in the same band —
    #    under_18 (age < 18), between_18_25 (18 <= age < 26), or over_26 (age >= 26).
    # Shift is bounded to ±30 days per policy.
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
    # @return [Integer] number of users processed
    def anonymize_users
      collection = db[:users]
      total = collection.count_documents({})
      log "\n--- Phase 2: Anonymizing Users (#{total}) ---"
      processed = 0

      collection.find.batch_size(batch_size).each_slice(batch_size) do |batch|
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
    # rubocop:disable Metrics/CyclomaticComplexity
    def build_census_member_update(doc, shift_days:, person_vals: nil)
      if person_vals
        fields = {
          'first_name' => person_vals['first_name'],
          'last_name' => person_vals['last_name'],
          'middle_name' => nil,
          'name_sfx' => nil
        }
        fields['encrypted_ssn'] = person_vals['encrypted_ssn'] if doc['encrypted_ssn'].present? && person_vals['encrypted_ssn'].present?
        fields['dob']           = person_vals['dob']           if @anonymize_dob && doc['dob'].present? && person_vals['dob'].present?
      else
        fields = {
          'first_name' => AnonymizedData.first_name,
          'last_name' => AnonymizedData.last_name,
          'middle_name' => nil,
          'name_sfx' => nil
        }
        fields['encrypted_ssn'] = AnonymizedData.encrypted_ssn if doc['encrypted_ssn'].present?
        fields['dob']           = AnonymizedData.shift_dob(doc['dob'].to_date, shift_days: shift_days) if @anonymize_dob && doc['dob'].present?
      end

      fields['address'] = anonymize_address_hash(doc['address']) if doc['address'].present?
      fields['email']   = anonymize_email_hash(doc['email'])     if doc['email'].present?
      fields
    end
    # rubocop:enable Metrics/CyclomaticComplexity

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
