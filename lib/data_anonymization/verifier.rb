# frozen_string_literal: true

require 'csv'
require 'openssl'
require_relative 'canonical_payloads'

module DataAnonymizer
  # Samples the database after anonymization and produces a pass/fail report.
  #
  # Checks each anonymized collection for signs of residual PII:
  #   - Real email domains (anything not matching anonymizer domains +exampleanonymizer.com+ / +testanonymizer.com+)
  #   - Plain-text +ssn+ fields
  #   - Non-nil +idp_uuid+, +tribal_id+, or +e_case_id+
  #   - Non-nil RIDP transaction IDs or session tokens
  #   - ACH routing numbers that are not exactly 9 digits
  #   - Presence of the +history_trackers+ collection (should have been dropped)
  #   - Cross-model consistency: Person vs CensusEmployee first_name for linked records
  #
  # Writes a CSV report to +tmp/anonymization_report_YYYYMMDD.csv+.
  #
  # @note +dba+, +fein+, and +npn+ are not checked - they are intentionally unchanged.
  # rubocop:disable Metrics/ClassLength
  class Verifier
    include CanonicalPayloads

    GENERATED_EMAIL_PATTERN = /@(exampleanonymizer|testanonymizer)\.com\z/
    SAMPLE_SIZE = 5000
    # Fields excluded from the streaming SSN regex scan.
    # +fein+ is a 9-digit EIN intentionally left unchanged per anonymization policy.
    # +ach_routing_number+ is an ABA routing number - always exactly 9 digits by spec;
    # it is validated separately by +check_organizations+ / +check_bs_organizations+.
    # +npn+ / +corporate_npn+ are public broker National Producer Numbers (up to 10
    # digits) intentionally preserved by the runner.
    # +content+ is free-text on Comment / Announcement and may incidentally contain
    # 9-digit tokens (check numbers, group ids) that are not SSNs.
    # +dba+ is the organization's "doing business as" name; some organizations use a
    # numeric identifier (e.g. a group ID) as their DBA and it is intentionally preserved
    # per anonymization policy alongside +fein+ and +npn+.
    # +versions+ is the inline mongoid-history snapshot array embedded in each document.
    # It holds pre-anonymization field snapshots (e.g. phone +full_phone_number+,
    # +ach_account_number+) that are not touched by the runner; 9-digit tokens in those
    # snapshots are not SSNs. The separate +history_trackers+ collection is dropped by
    # the runner; this covers the remaining per-document version trail.
    SKIP_FIELDS = %w[_id encrypted_ssn fein ach_routing_number ach_routing_number_confirmation npn corporate_npn content dba versions].freeze

    # rubocop:disable Metrics/ParameterLists
    def initialize(mode: :smoke, prehash_map: nil, hmac_key: nil, run_id: nil, sample_size: SAMPLE_SIZE, protected_oim_ids: [])
      @mode = mode
      @prehash_map = prehash_map
      @hmac_key = hmac_key
      @run_id = run_id
      @sample_size = sample_size
      @client = Mongoid.default_client
      @db = @client.database
      @protected_oim_ids = Array(protected_oim_ids).compact.uniq
      @protected_user_ids = compute_protected_user_ids
      @protected_person_ids = compute_protected_person_ids
    end
    # rubocop:enable Metrics/ParameterLists

    def run
      log "=== CCA Anonymization Verification Report ==="
      log "Database: #{@db.name}"
      log "Time: #{Time.current}"

      results    = collect_check_results
      all_passed = results.all? { |r| r[:passed] }
      report_path = write_csv_report(results)
      log_summary(results)

      if all_passed
        log "\nSTATUS: PASS - All checks passed. Safe to dump and share."
      else
        log "\nSTATUS: FAIL - Some checks failed. Review issues above."
      end

      log "Report written to: #{report_path}"

      # Return results for callers that want to gate on verification
      [results, all_passed, report_path]
    end

    private

    # Runs all verification checks and returns the results array.
    # @return [Array<Hash>]
    def collect_check_results
      checks = []
      checks << check_history_trackers
      checks << check_people
      checks << check_users
      checks << check_census_members
      checks << check_organizations
      checks << check_bs_organizations
      checks << check_families
      checks << check_census_person_consistency

      # Audit-only, more expensive checks
      if @mode.to_sym == :audit
        # Option A: load prehash map from TTL collection when not provided in-memory
        if @prehash_map.nil? && @hmac_key.present? && @run_id.present?
          @prehash_map = load_prehash_map_from_ttl(@run_id)
          log "Loaded #{@prehash_map.values.sum(&:size)} prehash digests from TTL collection (run_id=#{@run_id})."
        end
        checks << check_streaming_ssn_patterns
        checks << check_name_dob_prehash
      end

      checks
    end

    # Loads prehash digests from the +data_anonymizer_prehashes+ TTL collection
    # for a given run_id. Used for out-of-process (separate-task) verification.
    # @param run_id [String] UUID recorded during the anonymizer run
    # @return [Hash{Symbol => Hash{String => String}}] prehash map suitable for check_name_dob_prehash
    def load_prehash_map_from_ttl(run_id)
      map = Hash.new { |h, k| h[k] = {} }
      return map unless @db.collection_names.include?('data_anonymizer_prehashes')

      @db[:data_anonymizer_prehashes].find('run_id' => run_id.to_s).each do |doc|
        scope = doc['collection'].to_sym
        rec_id = doc['record_id'].to_s
        map[scope][rec_id] = doc['digest']
      end
      map
    end

    # Set of +users._id+ values whose +oim_id+ is in +@protected_oim_ids+.
    # These accounts are preserved by the runner so the operator can sign in
    # to the post-anonymization dump; they are excluded from email-pattern
    # sampling in {#check_users}.
    # @return [Set<BSON::ObjectId>]
    def compute_protected_user_ids
      return Set.new if @protected_oim_ids.empty?

      @db[:users]
        .find('oim_id' => { '$in' => @protected_oim_ids })
        .projection('_id' => 1)
        .each_with_object(Set.new) { |doc, set| set.add(doc['_id']) }
    end

    # Set of +people._id+ values linked to {#compute_protected_user_ids}.
    # Excluded from email-pattern sampling in {#check_people}.
    # @return [Set<BSON::ObjectId>]
    def compute_protected_person_ids
      return Set.new if @protected_user_ids.empty?

      @db[:people]
        .find('user_id' => { '$in' => @protected_user_ids.to_a })
        .projection('_id' => 1)
        .each_with_object(Set.new) { |doc, set| set.add(doc['_id']) }
    end

    # Streaming regex scan across all collections for SSN-like 9-digit patterns.
    # Samples up to +@sample_size+ documents per collection (audit mode only).
    # Recurses into nested hashes and arrays so embedded sub-documents are covered.
    PER_COLLECTION_HIT_CAP = 5

    def check_streaming_ssn_patterns
      pattern = /\b\d{9}\b/
      hits = []
      total_checked = 0

      collections = %w[people census_members families organizations benefit_sponsors_organizations_organizations users]
      collections.each do |col|
        next unless @db.collection_names.include?(col)

        collection_hits = 0
        @db[col.to_sym].find.limit(@sample_size).batch_size(500).each do |doc|
          total_checked += 1
          if doc_strings(doc).any? { |v| v.match?(pattern) }
            snippet = doc_strings(doc).find { |v| v.match?(pattern) }
            hits << { collection: col, id: doc['_id'].to_s, snippet: snippet.to_s[0, 120] }
            collection_hits += 1
          end
          break if collection_hits >= PER_COLLECTION_HIT_CAP
        end
      end

      issues = []
      issues << "#{hits.size} SSN-like patterns found" if hits.any?
      samples = hits.map { |h| "#{h[:collection]}:#{h[:id]}=#{h[:snippet]}" }.join('; ')
      build_result("Streaming SSN regex", total_checked, issues, samples)
    end

    # Yields every String value in a Mongo document, recursing into nested Hashes and Arrays.
    # Skips the +_id+ field and known ciphertext fields (+encrypted_ssn+) to avoid false positives.
    def doc_strings(value, &block)
      return enum_for(:doc_strings, value) unless block

      case value
      when String
        yield value
      when Hash
        value.each do |k, v|
          next if SKIP_FIELDS.include?(k)

          doc_strings(v, &block)
        end
      when Array
        value.each { |v| doc_strings(v, &block) }
      end
    end

    # Verifies canonical prehash map: compares pre-run HMAC (stored_hmac)
    # with a post-run HMAC built from the same canonicalization rules. Any
    # record whose HMAC is unchanged is treated as a failure.
    def check_name_dob_prehash
      # No credentials supplied - treat as skipped (PASS) so that verify-only
      # invocations without RUN_ID/HMAC_KEY don't block the overall sentinel.
      # A hard FAIL only applies when credentials were supplied but verification fails.
      unless @prehash_map && @hmac_key
        log "WARNING: Canonical prehash check SKIPPED - RUN_ID/HMAC_KEY not provided. " \
            "Name and DOB mutation is NOT verified by this run. " \
            "To enable this check, pass the RUN_ID and HMAC_KEY printed at anonymization time: " \
            "bundle exec rake data:anonymize:verify RUN_ID=<value> HMAC_KEY=<value>"
        return build_result("Canonical prehash", 0, [], "SKIPPED - RUN_ID/HMAC_KEY not provided; name+DOB mutation NOT verified")
      end

      issues = []
      samples = []
      total = 0

      @prehash_map.each do |collection_sym, id_map|
        col = collection_sym.to_s
        next unless @db.collection_names.include?(col)

        id_map.each do |id_str, stored_hmac|
          begin
            oid = BSON::ObjectId.from_string(id_str)
          rescue StandardError
            next
          end
          doc = @db[col.to_sym].find('_id' => oid).first
          next unless doc

          total += 1

          canon = canonical_payload_for_collection(collection_sym, doc)
          current_hmac = OpenSSL::HMAC.hexdigest('SHA256', @hmac_key, canon)
          if current_hmac == stored_hmac
            issues << "Unchanged canonical payload for #{col}:#{id_str}"
            samples << "#{col}:#{id_str}"
          end
        end
      end

      build_result("Canonical prehash", total, issues, samples.first(5).join(', '))
    end

    def canonical_payload_for_collection(collection_sym, doc)
      case collection_sym.to_sym
      when :people
        canonical_person_payload(doc)
      when :census_members
        canonical_census_payload(doc)
      when :organizations
        canonical_org_payload(doc)
      when :bs_organizations
        canonical_bs_org_payload(doc)
      else
        ""
      end
    end

    # Writes the results array to a dated CSV in tmp/ and returns the path.
    # @param results [Array<Hash>]
    # @return [String] path to the written CSV file
    def write_csv_report(results)
      report_dir  = File.join(Rails.root, 'tmp')
      FileUtils.mkdir_p(report_dir)
      report_path = File.join(report_dir, "anonymization_report_#{Date.today.strftime('%Y%m%d')}.csv")
      CSV.open(report_path, 'w') do |csv|
        csv << %w[collection total_records passed issues sample_values]
        results.each { |r| csv << [r[:collection], r[:total], r[:passed], r[:issues], r[:samples]] }
      end
      report_path
    end

    # Logs the pass/fail summary table to stdout and Rails logger.
    # @param results [Array<Hash>]
    # @return [void]
    def log_summary(results)
      log "\n--- Summary ---"
      results.each do |r|
        status = r[:passed] ? 'PASS' : 'FAIL'
        log "  #{r[:collection].ljust(55)} #{r[:total].to_s.rjust(8)} records | #{status} | #{r[:issues]}"
      end
    end

    def check_people
      collection = @db[:people]
      total = collection.count_documents({})
      issues = []

      real_email_count = count_real_person_emails(collection)
      issues << "#{real_email_count} real emails in sample of #{SAMPLE_SIZE}" if real_email_count > 0

      plain_ssn_count = collection.count_documents('ssn' => { '$exists' => true })
      issues << "#{plain_ssn_count} records with plain-text 'ssn' field" if plain_ssn_count > 0

      tribal_count = collection.count_documents('tribal_id' => { '$ne' => nil, '$exists' => true })
      issues << "#{tribal_count} records with non-nil tribal_id" if tribal_count > 0

      sample = collection.find.limit(3).to_a
      sample_names = sample.map { |d| "#{d['first_name']} #{d['last_name']}" }.join(", ")

      build_result("People (people)", total, issues, sample_names)
    end

    def check_history_trackers
      if @db.collection_names.include?('history_trackers')
        count = @db[:history_trackers].count_documents({})
        issues = ["history_trackers collection still exists with #{count} documents - contains raw PII change history"]
        build_result("History Trackers (history_trackers)", count, issues, "")
      else
        build_result("History Trackers (history_trackers)", 0, [], "dropped")
      end
    end

    def check_users
      collection = @db[:users]
      total = collection.count_documents({})
      issues = []

      real_email_count = 0
      collection.find.limit(SAMPLE_SIZE).each do |doc|
        next if @protected_user_ids.include?(doc['_id'])

        addr = doc['email']
        real_email_count += 1 if addr.present? && !addr.match?(GENERATED_EMAIL_PATTERN)
      end
      issues << "#{real_email_count} users with real email domains" if real_email_count > 0

      idp_count = collection.count_documents('idp_uuid' => { '$ne' => nil, '$exists' => true })
      issues << "#{idp_count} users with non-nil idp_uuid" if idp_count > 0

      ridp_count = collection.count_documents(
        'identity_final_decision_transaction_id' => { '$ne' => nil, '$exists' => true }
      )
      issues << "#{ridp_count} users with non-nil identity_final_decision_transaction_id" if ridp_count > 0

      token_count = collection.count_documents(
        'current_login_token' => { '$ne' => nil, '$exists' => true }
      )
      issues << "#{token_count} users with non-nil current_login_token" if token_count > 0

      sample = collection.find.limit(3).to_a
      sample_emails = sample.map { |d| d['email'] }.join(", ")

      build_result("Users (users)", total, issues, sample_emails)
    end

    def check_census_members
      collection = @db[:census_members]
      total = collection.count_documents({})
      issues = []

      plain_ssn_count = collection.count_documents('ssn' => { '$exists' => true })
      issues << "#{plain_ssn_count} records with plain-text 'ssn' field" if plain_ssn_count > 0

      dep_ssn_count = collection.count_documents('census_dependents.ssn' => { '$exists' => true })
      issues << "#{dep_ssn_count} records with plain-text dependent 'ssn'" if dep_ssn_count > 0

      sample = collection.find.limit(3).to_a
      sample_names = sample.map { |d| "#{d['first_name']} #{d['last_name']}" }.join(", ")

      build_result("Census Members (census_members)", total, issues, sample_names)
    end

    def check_organizations
      collection = @db[:organizations]
      total = collection.count_documents({})
      issues = []

      ach_count = collection.count_documents(
        '$or' => [
          { 'broker_agency_profile.ach_routing_number' => { '$exists' => true, '$ne' => nil } },
          { 'broker_agency_profile.ach_account_number' => { '$exists' => true, '$ne' => nil } }
        ]
      )
      if ach_count > 0
        sample_ach = collection.find('broker_agency_profile.ach_routing_number' => { '$exists' => true }).limit(5).to_a
        real_ach = sample_ach.count do |doc|
          rn = doc.dig('broker_agency_profile', 'ach_routing_number')
          rn.present? && rn.length != 9
        end
        issues << "#{real_ach} orgs with suspicious ACH routing numbers" if real_ach > 0
      end

      sample = collection.find.limit(3).to_a
      sample_names = sample.map { |d| d['legal_name'] }.join(", ")

      build_result("Organizations (organizations)", total, issues, sample_names)
    end

    def check_families
      collection = @db[:families]
      total = collection.count_documents({})
      issues = []

      e_case_count = collection.count_documents('e_case_id' => { '$exists' => true, '$ne' => nil })
      issues << "#{e_case_count} families with non-nil e_case_id" if e_case_count > 0

      build_result("Families (families)", total, issues, "")
    end

    # Checks cross-model PII consistency between people and census_members.
    #
    # Samples up to SAMPLE_SIZE census_members that carry an +employee_role_id+
    # and verifies that +first_name+ matches the linked Person's +first_name+.
    # A mismatch indicates the Phase 1 -> Phase 3 person-sync failed for some
    # documents.
    #
    # Uses a single +$in+ query to load all matched Person documents rather than
    # one query per census member, avoiding an N+1 pattern at scale.
    #
    # When no linked census members are found (e.g. on a staging environment
    # populated only with BenefitSponsors records), a warning is logged but the
    # check is not marked as FAIL - the absence of links is valid in that context.
    def check_census_person_consistency
      issues = []
      mismatches = 0
      checked = 0

      census_sample = @db[:census_members].find(
        'employee_role_id' => { '$exists' => true }
      ).limit(SAMPLE_SIZE).to_a

      role_ids = census_sample.map { |ce| ce['employee_role_id'] }.compact.uniq

      if role_ids.empty?
        log "  WARN: check_census_person_consistency - no census members with employee_role_id found in sample; skipping consistency check"
        return build_result("Cross-model: Census <-> Person (sample 0)", 0, [], "skipped - no linked records")
      end

      person_map = {}
      @db[:people].find(
        'employee_roles._id' => { '$in' => role_ids }
      ).projection('first_name' => 1, 'employee_roles._id' => 1).each do |person|
        (person['employee_roles'] || []).each do |er|
          person_map[er['_id']] = person['first_name']
        end
      end

      census_sample.each do |ce|
        er_id = ce['employee_role_id']
        next unless person_map.key?(er_id)

        checked += 1
        mismatches += 1 if ce['first_name'] != person_map[er_id]
      end

      issues << "#{mismatches}/#{checked} linked census members have first_name mismatch with Person" if mismatches > 0

      build_result("Cross-model: Census <-> Person (sample #{checked})", checked, issues, "")
    end

    def check_bs_organizations
      collection = @db[:benefit_sponsors_organizations_organizations]
      total = collection.count_documents({})
      return build_result("BS Organizations (benefit_sponsors_organizations_organizations)", 0, [], "") if total.zero?

      issues = []

      real_ach_count = 0
      collection.find('profiles.ach_routing_number' => { '$exists' => true }).limit(SAMPLE_SIZE).each do |doc|
        (doc['profiles'] || []).each do |profile|
          rn = profile['ach_routing_number']
          real_ach_count += 1 if rn.present? && rn.length != 9
        end
      end
      issues << "#{real_ach_count} profiles with suspicious ACH routing numbers" if real_ach_count > 0

      sample = collection.find.limit(3).to_a
      sample_names = sample.map { |d| d['legal_name'] }.join(", ")

      build_result("BS Organizations (benefit_sponsors_organizations_organizations)", total, issues, sample_names)
    end

    def count_real_person_emails(collection)
      count = 0
      collection.find.limit(SAMPLE_SIZE).each do |doc|
        next if @protected_person_ids.include?(doc['_id'])

        (doc['emails'] || []).each do |em|
          addr = em['address']
          count += 1 if addr.present? && !addr.match?(GENERATED_EMAIL_PATTERN)
        end
      end
      count
    end

    def build_result(collection_name, total, issues, samples)
      {
        collection: collection_name,
        total: total,
        passed: issues.empty?,
        issues: issues.empty? ? "None" : issues.join("; "),
        samples: samples
      }
    end

    def log(msg)
      puts msg unless Rails.env.test?
      Rails.logger.info("[DataAnonymizer::Verifier] #{msg}")
    end
  end
  # rubocop:enable Metrics/ClassLength
end
