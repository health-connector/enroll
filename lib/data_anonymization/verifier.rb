# frozen_string_literal: true

require 'csv'

module DataAnonymizer
  # Samples the database after anonymization and produces a pass/fail report.
  #
  # Checks each anonymized collection for signs of residual PII:
  #   - Real email domains (anything not matching +@example.com+)
  #   - Plain-text +ssn+ fields
  #   - Non-nil +idp_uuid+, +tribal_id+, or +e_case_id+
  #   - Non-nil RIDP transaction IDs or session tokens
  #   - ACH routing numbers that are not exactly 9 digits
  #   - Presence of the +history_trackers+ collection (should have been dropped)
  #   - Cross-model consistency: Person vs CensusEmployee first_name for linked records
  #
  # Writes a CSV report to +tmp/anonymization_report_YYYYMMDD.csv+.
  #
  # @note +dba+, +fein+, and +npn+ are not checked — they are intentionally unchanged.
  class Verifier
    GENERATED_EMAIL_PATTERN = /@example\.com\z/
    SAMPLE_SIZE = 5000

    def initialize
      @client = Mongoid.default_client
      @db = @client.database
    end

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
    end

    private

    # Runs all verification checks and returns the results array.
    # @return [Array<Hash>]
    def collect_check_results
      [
        check_history_trackers,
        check_people,
        check_users,
        check_census_members,
        check_organizations,
        check_bs_organizations,
        check_families,
        check_census_person_consistency
      ]
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

      real_email_count = 0
      collection.find.limit(SAMPLE_SIZE).each do |doc|
        (doc['emails'] || []).each do |em|
          addr = em['address']
          real_email_count += 1 if addr.present? && !addr.match?(GENERATED_EMAIL_PATTERN)
        end
      end
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
        issues = ["history_trackers collection still exists with #{count} documents — contains raw PII change history"]
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
    # A mismatch indicates the Phase 1 → Phase 3 person-sync failed for some
    # documents.
    #
    # Uses a single +$in+ query to load all matched Person documents rather than
    # one query per census member, avoiding an N+1 pattern at scale.
    #
    # When no linked census members are found (e.g. on a staging environment
    # populated only with BenefitSponsors records), a warning is logged but the
    # check is not marked as FAIL — the absence of links is valid in that context.
    def check_census_person_consistency
      issues = []
      mismatches = 0
      checked = 0

      census_sample = @db[:census_members].find(
        'employee_role_id' => { '$exists' => true }
      ).limit(SAMPLE_SIZE).to_a

      role_ids = census_sample.map { |ce| ce['employee_role_id'] }.compact.uniq

      if role_ids.empty?
        log "  WARN: check_census_person_consistency — no census members with employee_role_id found in sample; skipping consistency check"
        return build_result("Cross-model: Census ↔ Person (sample 0)", 0, [], "skipped — no linked records")
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

      build_result("Cross-model: Census ↔ Person (sample #{checked})", checked, issues, "")
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
end
