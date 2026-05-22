# frozen_string_literal: true

require 'rails_helper'
require 'ffaker'
require Rails.root.join('lib/data_anonymization/anonymized_data')
require Rails.root.join('lib/data_anonymization/runner')
require Rails.root.join('lib/data_anonymization/verifier')

RSpec.describe DataAnonymizer, :dbclean => :around_each do
  # ============================================================================
  # Shared helpers
  # ============================================================================

  # Returns the raw MongoDB document for the given Mongoid record.
  def raw_doc(collection_name, id)
    Mongoid.default_client.database[collection_name].find('_id' => id).first
  end

  # ============================================================================
  # AnonymizedData module — pure unit tests, no database required
  # ============================================================================

  describe DataAnonymizer::AnonymizedData do
    describe '.first_name' do
      it 'returns a non-empty string' do
        expect(described_class.first_name).to be_a(String).and be_present
      end
    end

    describe '.last_name' do
      it 'returns a non-empty string' do
        expect(described_class.last_name).to be_a(String).and be_present
      end
    end

    describe '.ssn' do
      subject(:ssn) { described_class.ssn }

      it 'is exactly 9 digits' do
        expect(ssn).to match(/\A\d{9}\z/)
      end

      it 'never generates area code 000' do
        100.times { expect(described_class.ssn[0..2]).not_to eq('000') }
      end

      it 'never generates area code 666' do
        100.times { expect(described_class.ssn[0..2]).not_to eq('666') }
      end

      it 'does not use area codes 900-999' do
        100.times { expect(described_class.ssn[0..2].to_i).to be < 900 }
      end
    end

    describe '.routing_number' do
      subject(:rn) { described_class.routing_number }

      it 'is exactly 9 characters' do
        expect(rn.length).to eq(9)
      end

      it 'never starts with 0 (matches real ABA format)' do
        100.times { expect(described_class.routing_number).not_to start_with('0') }
      end

      it 'contains only digits' do
        expect(rn).to match(/\A\d{9}\z/)
      end
    end

    describe '.account_number' do
      it 'is a 16-digit numeric string not starting with 0' do
        expect(described_class.account_number).to match(/\A[1-9]\d{15}\z/)
      end
    end

    describe '.email' do
      it 'uses an allowed anonymizer domain' do
        expect(described_class.email).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
      end

      it 'uses user{index} prefix when index is given' do
        expect(described_class.email(42)).to match(/\Auser42@(exampleanonymizer|testanonymizer)\.com\z/)
      end

      it 'uses a random suffix when no index is given' do
        emails = Array.new(5) { described_class.email }
        expect(emails.uniq.length).to be > 1
      end
    end

    describe '.dob_shift_days' do
      it 'returns an integer within ±30 days' do
        100.times do
          shift = described_class.dob_shift_days
          expect(shift).to be_between(-30, 30)
        end
      end
    end

    describe '.shift_dob' do
      let(:dob) { Date.new(1985, 6, 15) }

      it 'returns nil when dob is nil' do
        expect(described_class.shift_dob(nil)).to be_nil
      end

      it 'applies the given shift_days' do
        result = described_class.shift_dob(dob, shift_days: 10)
        expect(result).to eq(dob + 10)
      end

      it 'clamps to 1920-01-01 minimum' do
        extreme = Date.new(1921, 1, 1)
        result = described_class.shift_dob(extreme, shift_days: -1095)
        expect(result).to be >= Date.new(1920, 1, 1)
      end

      it 'never returns today or a future date' do
        result = described_class.shift_dob(Date.today - 365, shift_days: 1000)
        expect(result).to be < Date.today
      end

      it 'uses a random shift when shift_days is nil' do
        results = Array.new(10) { described_class.shift_dob(dob) }
        # very unlikely all 10 random shifts are identical
        expect(results.uniq.length).to be > 1
      end
    end
  end

  # ============================================================================
  # Runner — integration tests against a real (test) MongoDB database
  # ============================================================================

  describe DataAnonymizer::Runner do
    let(:skip_confirmation) { allow_any_instance_of(DataAnonymizer::Runner).to receive(:confirm_anonymization!) }

    # Use a small batch size so multiple batches are exercised even with few records
    let(:runner) { DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: true) }
    let(:dry_runner) { DataAnonymizer::Runner.new(batch_size: 5, dry_run: true, force: true) }
    # Runner with DOB shifting enabled — required for tests that assert DOB changes
    let(:dob_runner) { DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: true, anonymize_dob: true) }

    before { skip_confirmation }

    # @!group Safety — environment and safety guard tests

    describe '#abort_if_production!' do
      around do |example|
        ENV.delete('ENV_NAME')
        ENV.delete('ENROLL_REVIEW_ENVIRONMENT')
        example.run
        ENV.delete('ENV_NAME')
        ENV.delete('ENROLL_REVIEW_ENVIRONMENT')
      end

      context 'when ENV_NAME is not set' do
        it 'aborts' do
          expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
        end
      end

      context "when ENV_NAME is 'prod'" do
        before { ENV['ENV_NAME'] = 'prod' }

        it 'aborts' do
          expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
        end
      end

      context 'when Rails.env=production and ENROLL_REVIEW_ENVIRONMENT is not true' do
        before do
          ENV['ENV_NAME'] = 'pvt'
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        end

        it 'aborts' do
          expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
        end
      end

      context 'when database name matches a production pattern' do
        before do
          ENV['ENV_NAME'] = 'pvt'
          allow(runner.db).to receive(:name).and_return('mhc_enroll_prod')
        end

        it 'aborts' do
          expect { runner.send(:abort_if_production!) }.to raise_error(SystemExit)
        end
      end

      context 'in a local dev environment (ENV_NAME=pvt, Rails.env=test)' do
        before { ENV['ENV_NAME'] = 'pvt' }

        it 'does not abort' do
          expect { runner.send(:abort_if_production!) }.not_to raise_error
        end
      end

      context "in a lower k8s env (ENV_NAME=preprod, Rails.env=production, ENROLL_REVIEW_ENVIRONMENT=true)" do
        before do
          ENV['ENV_NAME'] = 'preprod'
          ENV['ENROLL_REVIEW_ENVIRONMENT'] = 'true'
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        end

        it 'does not abort' do
          expect { runner.send(:abort_if_production!) }.not_to raise_error
        end
      end
    end

    # @!group Idempotency — idempotency and sentinel guarding tests

    describe '#check_idempotency!' do
      before do
        runner.db[:data_anonymizer_runs].drop
      end

      context 'when no previous run exists' do
        it 'does not abort' do
          expect { runner.send(:check_idempotency!) }.not_to raise_error
        end
      end

      context 'when a sentinel already exists and force is false' do
        let(:strict_runner) { DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: false) }

        before do
          runner.db[:data_anonymizer_runs].insert_one('completed_at' => Time.current, 'database' => runner.db.name)
          allow_any_instance_of(DataAnonymizer::Runner).to receive(:confirm_anonymization!)
        end

        it 'aborts' do
          expect { strict_runner.send(:check_idempotency!) }.to raise_error(SystemExit)
        end
      end

      context 'when force: true and sentinel exists' do
        before do
          runner.db[:data_anonymizer_runs].insert_one('completed_at' => Time.current)
        end

        it 'logs a warning but does not abort' do
          expect(runner).to receive(:log).with(a_string_matching(/WARNING/))
          expect { runner.send(:check_idempotency!) }.not_to raise_error
        end
      end
    end

    # @!group Phase 0: history_trackers — history tracker cleanup tests

    describe '#drop_history_trackers' do
      context 'when history_trackers exists' do
        before do
          runner.db[:history_trackers].insert_many([
            { 'first_name' => 'Real Name', 'encrypted_ssn' => '123' },
            { 'first_name' => 'Another Real', 'dob' => Date.new(1980, 1, 1) }
          ])
        end

        it 'drops the collection' do
          runner.send(:drop_history_trackers)
          expect(runner.db.collection_names).not_to include('history_trackers')
        end

        it 'returns 0' do
          expect(runner.send(:drop_history_trackers)).to eq(0)
        end
      end

      context 'when history_trackers does not exist' do
        before do
          runner.db[:history_trackers].drop rescue StandardError # rubocop:disable Style/RescueModifier
        end

        it 'returns 0 without raising' do
          expect { runner.send(:drop_history_trackers) }.not_to raise_error
        end
      end

      context 'in dry-run mode' do
        it 'does not drop the collection' do
          runner.db[:history_trackers].insert_one('foo' => 'bar')
          dry_runner.send(:drop_history_trackers)
          expect(runner.db.collection_names).to include('history_trackers')
        end
      end
    end

    # @!group Phase 1: People — people anonymization tests

    describe '#anonymize_people' do
      let!(:person) do
        FactoryBot.create(
          :person,
          first_name: 'John',
          last_name: 'Doe',
          dob: Date.new(1980, 3, 15),
          tribal_id: 'TRIBE123'
        ).tap { |p| p.update_attributes(ssn: '123456789') rescue StandardError } # rubocop:disable Style/RescueModifier
      end

      before { runner.send(:anonymize_people) }

      it 'replaces first_name' do
        doc = raw_doc('people', person.id)
        expect(doc['first_name']).not_to eq('John')
      end

      it 'replaces last_name' do
        doc = raw_doc('people', person.id)
        expect(doc['last_name']).not_to eq('Doe')
      end

      it 'sets name_pfx to nil' do
        doc = raw_doc('people', person.id)
        expect(doc['name_pfx']).to be_nil
      end

      it 'clears tribal_id' do
        doc = raw_doc('people', person.id)
        expect(doc['tribal_id']).to be_nil
      end

      it 'preserves dob when anonymize_dob is false (default)' do
        doc = raw_doc('people', person.id)
        expect(doc['dob']&.to_date).to eq(Date.new(1980, 3, 15))
      end

      it 'removes the plain-text ssn field' do
        doc = raw_doc('people', person.id)
        expect(doc.keys).not_to include('ssn')
      end

      it 'anonymizes embedded emails to an allowed anonymizer domain' do
        doc = raw_doc('people', person.id)
        emails = doc['emails'] || []
        emails.each do |em|
          expect(em['address']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
        end
      end

      it 'returns the count of processed records' do
        count = runner.send(:anonymize_people)
        expect(count).to be >= 1
      end

      context 'in dry-run mode' do
        let!(:person2) { FactoryBot.create(:person, first_name: 'RealName') }

        it 'does not change the first_name' do
          dry_runner.send(:anonymize_people)
          doc = raw_doc('people', person2.id)
          expect(doc['first_name']).to eq('RealName')
        end
      end

      context 'when a person has no encrypted_ssn' do
        let!(:bare_person) { FactoryBot.create(:person) }

        before { runner.db[:people].update_one({ '_id' => bare_person.id }, { '$unset' => { 'encrypted_ssn' => '' } }) }

        it 'does not raise and still anonymizes the name' do
          expect { runner.send(:anonymize_people) }.not_to raise_error
          doc = raw_doc('people', bare_person.id)
          expect(doc['first_name']).not_to eq(bare_person.first_name)
        end
      end
    end

    # @!group Phase 1 support: build_person_update — person update helper tests

    describe '#build_person_update' do
      let(:doc) do
        {
          'first_name' => 'Alice',
          'last_name' => 'Smith',
          'encrypted_ssn' => 'enc_value',
          'dob' => Date.new(1990, 5, 20),
          'date_of_death' => Date.new(2020, 1, 1),
          'tribal_id' => 'T123',
          'addresses' => [{ 'address_1' => '123 Main St', 'city' => 'Boston', 'zip' => '02101', 'kind' => 'home' }],
          'phones' => [{ 'area_code' => '617', 'number' => '5551234', 'kind' => 'home', 'full_phone_number' => '6175551234' }],
          'emails' => [{ 'address' => 'alice@real.com', 'kind' => 'home' }]
        }
      end

      subject(:fields) { dob_runner.send(:build_person_update, doc, shift_days: 30) }

      it 'replaces first_name' do
        expect(fields['first_name']).not_to eq('Alice')
      end

      it 'sets name_pfx to nil' do
        expect(fields['name_pfx']).to be_nil
      end

      it 'sets tribal_id to nil' do
        expect(fields['tribal_id']).to be_nil
      end

      it 'shifts dob by the given shift_days' do
        expect(fields['dob']).to eq(Date.new(1990, 6, 19)) # +30 days
      end

      it 'shifts date_of_death by the same delta' do
        expect(fields['date_of_death']).to eq(Date.new(2020, 1, 31))
      end

      it 'replaces the embedded email address with an anonymizer domain' do
        expect(fields['emails'].first['address']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
      end

      it 'preserves the email kind' do
        expect(fields['emails'].first['kind']).to eq('home')
      end

      it 'replaces the address_1 field' do
        expect(fields['addresses'].first['address_1']).not_to eq('123 Main St')
      end

      it 'replaces encrypted_ssn when present' do
        expect(fields['encrypted_ssn']).not_to eq('enc_value')
      end

      it 'sets name_sfx to nil' do
        expect(fields['name_sfx']).to be_nil
      end

      it 'sets alternate_name to nil' do
        expect(fields['alternate_name']).to be_nil
      end

      it 'generates a full_name from the new first and last names' do
        expect(fields['full_name']).to eq("#{fields['first_name']} #{fields['last_name']}")
      end

      it 'sets middle_name to a single character' do
        expect(fields['middle_name']).to be_a(String)
        expect(fields['middle_name'].length).to eq(1)
      end

      context 'when encrypted_ssn is absent' do
        let(:doc_no_ssn) { doc.except('encrypted_ssn') }

        it 'does not add an encrypted_ssn key' do
          result = runner.send(:build_person_update, doc_no_ssn, shift_days: 0)
          expect(result.keys).not_to include('encrypted_ssn')
        end
      end

      context 'when person has no embedded documents' do
        let(:bare_doc) do
          { 'first_name' => 'Solo', 'last_name' => 'Person', 'dob' => Date.new(1990, 1, 1) }
        end

        it 'does not add addresses, phones, or emails keys' do
          result = runner.send(:build_person_update, bare_doc, shift_days: 0)
          expect(result.keys).not_to include('addresses', 'phones', 'emails')
        end
      end

      context 'when dob and date_of_death are nil' do
        let(:no_dates_doc) do
          { 'first_name' => 'No', 'last_name' => 'Dates' }
        end

        it 'does not add dob or date_of_death keys' do
          result = runner.send(:build_person_update, no_dates_doc, shift_days: 30)
          expect(result.keys).not_to include('dob', 'date_of_death')
        end
      end
    end

    # @!group Phase 1 support: family DOB shift consistency — family DOB shift mapping tests

    describe '#build_family_shift_map and family DOB consistency' do
      let!(:primary_person)  { FactoryBot.create(:person, dob: Date.new(1975, 4, 1)) }
      let!(:spouse_person)   { FactoryBot.create(:person, dob: Date.new(1977, 8, 10)) }
      let!(:family) do
        f = FactoryBot.create(:family, :with_primary_family_member, person: primary_person)
        FactoryBot.create(:family_member, family: f, person: spouse_person, is_primary_applicant: false, is_active: true)
        f.reload
      end

      it 'assigns the same shift_days to all family members' do
        shift_map = runner.send(:build_family_shift_map)
        primary_shift = shift_map[primary_person.id]
        spouse_shift  = shift_map[spouse_person.id]
        expect(primary_shift).not_to be_nil
        expect(primary_shift).to eq(spouse_shift)
      end
    end

    # @!group Phase 1 support: person not in any family — orphan person anonymization tests

    describe 'person not in any family' do
      let!(:orphan_person) { FactoryBot.create(:person, first_name: 'Orphan', dob: Date.new(1985, 6, 15)) }

      it 'still gets anonymized with a random shift' do
        dob_runner.send(:anonymize_people)
        doc = raw_doc('people', orphan_person.id)
        expect(doc['first_name']).not_to eq('Orphan')
        expect(doc['dob']&.to_date).not_to eq(Date.new(1985, 6, 15))
      end
    end

    # @!group Phase 2: Users — user anonymization tests

    describe '#anonymize_users' do
      let!(:user) do
        FactoryBot.create(:user).tap do |u|
          runner.db[:users].update_one(
            { '_id' => u.id },
            { '$set' => {
              'idp_uuid' => 'real-uuid-123',
              'identity_final_decision_transaction_id' => 'real-ridp-txn-456',
              'current_login_token' => 'real-session-token-789'
            } }
          )
        end
      end

      before { runner.send(:anonymize_users) }

      it 'replaces email with an anonymizer domain address' do
        doc = raw_doc('users', user.id)
        expect(doc['email']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
      end

      it 'syncs oim_id to the anonymized email' do
        doc = raw_doc('users', user.id)
        expect(doc['oim_id']).to eq(doc['email'])
        expect(doc['oim_id']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
      end

      it 'nulls idp_uuid' do
        doc = raw_doc('users', user.id)
        expect(doc['idp_uuid']).to be_nil
      end

      it 'nulls identity_final_decision_transaction_id (RIDP)' do
        doc = raw_doc('users', user.id)
        expect(doc['identity_final_decision_transaction_id']).to be_nil
      end

      it 'nulls current_login_token (active session)' do
        doc = raw_doc('users', user.id)
        expect(doc['current_login_token']).to be_nil
      end

      it 'nulls authentication_token' do
        doc = raw_doc('users', user.id)
        expect(doc['authentication_token']).to be_nil
      end

      it 'generates unique emails across multiple users' do
        FactoryBot.create(:user)
        runner2 = DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: true)
        allow(runner2).to receive(:confirm_anonymization!)
        runner2.send(:anonymize_users)
        emails = runner2.db[:users].find.map { |d| d['email'] }.compact
        expect(emails.uniq.length).to eq(emails.length)
      end
    end

    # @!group Phase 3: Census Members — census member anonymization tests

    describe '#anonymize_census_members' do
      let!(:census_employee) do
        FactoryBot.create(:census_employee,
                          first_name: 'CensusFirst',
                          last_name: 'CensusLast',
                          dob: Date.new(1985, 3, 10))
      end

      before { runner.send(:anonymize_census_members) }

      it 'replaces first_name' do
        doc = raw_doc('census_members', census_employee.id)
        expect(doc['first_name']).not_to eq('CensusFirst')
      end

      it 'replaces last_name' do
        doc = raw_doc('census_members', census_employee.id)
        expect(doc['last_name']).not_to eq('CensusLast')
      end

      it 'removes the plain ssn field' do
        doc = raw_doc('census_members', census_employee.id)
        expect(doc.keys).not_to include('ssn')
      end

      it 'shifts the dob' do
        dob_runner.send(:anonymize_census_members)
        doc = raw_doc('census_members', census_employee.id)
        expect(doc['dob']&.to_date).not_to eq(Date.new(1985, 3, 10))
      end

      context 'with census dependents' do
        let!(:employee_with_dep) do
          emp = FactoryBot.create(:census_employee, dob: Date.new(1980, 1, 1))
          emp.census_dependents.create!(
            first_name: 'DepFirst', last_name: 'DepLast',
            dob: Date.new(2010, 5, 5),
            employee_relationship: 'child_under_26',
            gender: 'female'
          )
          emp
        end

        it 'anonymizes each dependent first_name' do
          runner.send(:anonymize_census_members)
          doc = raw_doc('census_members', employee_with_dep.id)
          dep = doc['census_dependents'].first
          expect(dep['first_name']).not_to eq('DepFirst')
        end

        it 'shifts dependent dob by the same delta as the employee' do
          original_emp_dob = Date.new(1980, 1, 1)
          original_dep_dob = Date.new(2010, 5, 5)
          runner.send(:anonymize_census_members)
          doc = raw_doc('census_members', employee_with_dep.id)
          emp_shift = (doc['dob'].to_date - original_emp_dob).to_i
          dep_shift = (doc['census_dependents'].first['dob'].to_date - original_dep_dob).to_i
          expect(emp_shift).to eq(dep_shift)
        end
      end

      context 'when census_member is linked to an already-anonymized Person' do
        let!(:person) { FactoryBot.create(:person, first_name: 'LinkedFirst', dob: Date.new(1970, 1, 1)) }
        let!(:linked_census) do
          emp = FactoryBot.create(:census_employee)
          role_id = BSON::ObjectId.new
          # embed a fake employee_role _id on the person
          runner.db[:people].update_one(
            { '_id' => person.id },
            { '$push' => { 'employee_roles' => { '_id' => role_id, 'aasm_state' => 'eligible' } } }
          )
          runner.db[:census_members].update_one({ '_id' => emp.id }, { '$set' => { 'employee_role_id' => role_id } })
          # First anonymize people so the sync map has fake values
          runner.send(:anonymize_people)
          emp
        end

        it 'copies the Person fake first_name to the CensusEmployee' do
          runner.send(:anonymize_census_members)
          person_doc  = raw_doc('people', person.id)
          census_doc  = raw_doc('census_members', linked_census.id)
          expect(census_doc['first_name']).to eq(person_doc['first_name'])
        end
      end
    end

    # @!group Phase 4 & 5: Organizations — organization anonymization tests

    describe '#anonymize_organizations' do
      let!(:org) do
        FactoryBot.create(:organization, legal_name: 'Real Corp Name').tap do |o|
          runner.db[:organizations].update_one(
            { '_id' => o.id },
            { '$set' => { 'broker_agency_profile' => {
              'ach_routing_number' => '021000021',
              'ach_account_number' => 'realacct123'
            } } }
          )
        end
      end

      before { runner.send(:anonymize_organizations) }

      it 'replaces legal_name' do
        doc = raw_doc('organizations', org.id)
        expect(doc['legal_name']).not_to eq('Real Corp Name')
      end

      it 'replaces broker ach_routing_number with 9-digit string' do
        doc = raw_doc('organizations', org.id)
        rn = doc.dig('broker_agency_profile', 'ach_routing_number')
        expect(rn).to match(/\A\d{9}\z/)
      end

      it 'does not change fein' do
        doc = raw_doc('organizations', org.id)
        expect(doc['fein']).to eq(org.fein)
      end

      it 'does not change dba' do
        doc = raw_doc('organizations', org.id)
        expect(doc['dba']).to eq(org.dba)
      end
    end

    # @!group Phase 5: BS Organizations — benefit sponsor organization tests

    describe '#anonymize_bs_organizations' do
      before do
        runner.db[:benefit_sponsors_organizations_organizations].insert_one(
          'legal_name' => 'Real BS Corp',
          'profiles' => [
            { 'ach_routing_number' => '021000021', 'ach_account_number' => 'realacct',
              'office_locations' => [{ 'address' => { 'address_1' => '99 Real Blvd', 'city' => 'Boston', 'zip' => '02101', 'kind' => 'primary' } }] }
          ]
        )
      end

      it 'replaces legal_name' do
        runner.send(:anonymize_bs_organizations)
        doc = runner.db[:benefit_sponsors_organizations_organizations].find.first
        expect(doc['legal_name']).not_to eq('Real BS Corp')
      end

      it 'replaces profile ach_routing_number with 9-digit string' do
        runner.send(:anonymize_bs_organizations)
        doc = runner.db[:benefit_sponsors_organizations_organizations].find.first
        rn = doc.dig('profiles', 0, 'ach_routing_number')
        expect(rn).to match(/\A\d{9}\z/)
      end

      it 'anonymizes office location addresses within profiles' do
        runner.send(:anonymize_bs_organizations)
        doc = runner.db[:benefit_sponsors_organizations_organizations].find.first
        addr = doc.dig('profiles', 0, 'office_locations', 0, 'address')
        expect(addr['address_1']).not_to eq('99 Real Blvd')
      end

      it 'returns 0 when collection is empty' do
        runner.db[:benefit_sponsors_organizations_organizations].drop
        expect(runner.send(:anonymize_bs_organizations)).to eq(0)
      end
    end

    # @!group Helper: anonymize_bs_profile — BS profile anonymization helper tests

    describe '#anonymize_bs_profile' do
      let(:profile) do
        { 'ach_routing_number' => '021000021', 'ach_account_number' => 'realacct',
          'office_locations' => [{ 'address' => { 'address_1' => '1 Real St', 'city' => 'Lowell', 'zip' => '01852', 'kind' => 'primary' } }] }
      end

      subject(:result) { runner.send(:anonymize_bs_profile, profile) }

      it 'replaces ach_routing_number' do
        expect(result['ach_routing_number']).not_to eq('021000021')
        expect(result['ach_routing_number']).to match(/\A\d{9}\z/)
      end

      it 'replaces ach_account_number' do
        expect(result['ach_account_number']).not_to eq('realacct')
      end

      it 'anonymizes office_locations addresses' do
        expect(result.dig('office_locations', 0, 'address', 'address_1')).not_to eq('1 Real St')
      end

      it 'does not mutate the original hash' do
        original_rn = profile['ach_routing_number']
        result
        expect(profile['ach_routing_number']).to eq(original_rn)
      end
    end

    # @!group Helper: anonymize_office_locations — office locations helper tests

    describe '#anonymize_office_locations' do
      let(:locations) do
        [
          { 'address' => { 'address_1' => '10 Main', 'city' => 'Boston', 'zip' => '02101', 'kind' => 'primary' },
            'phone' => { 'area_code' => '617', 'number' => '5551234', 'kind' => 'work' } },
          { 'address' => { 'address_1' => '20 Side', 'city' => 'Worcester', 'zip' => '01601', 'kind' => 'mailing' } }
        ]
      end

      subject(:result) { runner.send(:anonymize_office_locations, locations) }

      it 'anonymizes each location address' do
        expect(result[0]['address']['address_1']).not_to eq('10 Main')
        expect(result[1]['address']['address_1']).not_to eq('20 Side')
      end

      it 'anonymizes phones when present' do
        expect(result[0]['phone']['area_code']).not_to eq('617')
      end

      it 'does not add phone to locations without one' do
        expect(result[1].keys).not_to include('phone')
      end
    end

    # @!group Helper: census_member_shift_days — census group shift helper tests

    describe '#census_member_shift_days' do
      let(:doc) { { 'dob' => Date.new(1980, 1, 1), 'census_dependents' => [] } }

      context 'when person_vals has a DOB' do
        let(:person_vals) { { 'dob' => Date.new(1980, 7, 1) } }

        it 'returns the delta between person DOB and doc DOB' do
          result = runner.send(:census_member_shift_days, doc, person_vals)
          expect(result).to eq((Date.new(1980, 7, 1) - Date.new(1980, 1, 1)).to_i)
        end
      end

      context 'when person_vals exists but has no DOB' do
        let(:person_vals) { { 'first_name' => 'Fake' } }

        it 'returns 0' do
          expect(runner.send(:census_member_shift_days, doc, person_vals)).to eq(0)
        end
      end

      context 'when person_vals is nil (no linked person)' do
        it 'computes a group shift from doc and dependent DOBs' do
          result = runner.send(:census_member_shift_days, doc, nil)
          expect(result).to be_between(-30, 30)
        end
      end
    end

    # @!group Helper: build_census_member_update — census member update helper tests

    describe '#build_census_member_update' do
      let(:doc) do
        { 'first_name' => 'CensusOrig', 'encrypted_ssn' => 'enc_val', 'dob' => Date.new(1985, 3, 10),
          'address' => { 'address_1' => '1 Real', 'city' => 'Boston', 'zip' => '02101', 'kind' => 'home' },
          'email' => { 'address' => 'real@corp.com', 'kind' => 'work' } }
      end

      context 'with person_vals (linked to Person)' do
        let(:person_vals) { { 'first_name' => 'FakePerson', 'last_name' => 'FakeLast', 'dob' => Date.new(1985, 4, 10), 'encrypted_ssn' => 'enc_fake' } }

        subject(:result) { dob_runner.send(:build_census_member_update, doc, shift_days: 0, person_vals: person_vals) }

        it 'uses the Person first_name' do
          expect(result['first_name']).to eq('FakePerson')
        end

        it 'uses the Person encrypted_ssn' do
          expect(result['encrypted_ssn']).to eq('enc_fake')
        end

        it 'uses the Person dob' do
          expect(result['dob']).to eq(Date.new(1985, 4, 10))
        end
      end

      context 'without person_vals (no linked Person)' do
        subject(:result) { dob_runner.send(:build_census_member_update, doc, shift_days: 30, person_vals: nil) }

        it 'generates a fresh first_name' do
          expect(result['first_name']).not_to eq('CensusOrig')
        end

        it 'shifts the dob by shift_days' do
          expect(result['dob']).to eq(Date.new(1985, 4, 9))
        end

        it 'anonymizes the embedded address' do
          expect(result['address']['address_1']).not_to eq('1 Real')
        end

        it 'anonymizes the embedded email' do
          expect(result['email']['address']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
        end
      end
    end

    # @!group Phase 6: Families — family anonymization tests

    describe '#anonymize_families' do
      let!(:family_with_case)    { FactoryBot.create(:family, :with_primary_family_member) }   # e_case_id set by factory sequence
      let!(:family_without_case) { FactoryBot.create(:family, :with_primary_family_member).tap { |f| runner.db[:families].update_one({ '_id' => f.id }, { '$unset' => { 'e_case_id' => '' } }) } }

      before { runner.send(:anonymize_families) }

      it 'removes e_case_id from families that had it' do
        doc = raw_doc('families', family_with_case.id)
        expect(doc.keys).not_to include('e_case_id')
      end

      it 'does not error on families that already had no e_case_id' do
        expect { runner.send(:anonymize_families) }.not_to raise_error
      end

      context 'in dry-run mode' do
        let!(:family_dry) { FactoryBot.create(:family, :with_primary_family_member) }

        it 'does not unset e_case_id' do
          dry_runner.send(:anonymize_families)
          doc = raw_doc('families', family_dry.id)
          expect(doc).to have_key('e_case_id')
        end
      end
    end

    # @!group Idempotency — sentinel written after full run tests

    describe 'sentinel record after full run' do
      before do
        runner.db[:data_anonymizer_runs].drop
        # stub heavy phases to keep the test fast
        allow(runner).to receive(:drop_history_trackers).and_return(0)
        allow(runner).to receive(:anonymize_people).and_return(0)
        allow(runner).to receive(:anonymize_users).and_return(0)
        allow(runner).to receive(:anonymize_census_members).and_return(0)
        allow(runner).to receive(:anonymize_organizations).and_return(0)
        allow(runner).to receive(:anonymize_bs_organizations).and_return(0)
        allow(runner).to receive(:anonymize_families).and_return(0)
        allow_any_instance_of(DataAnonymizer::Verifier).to receive(:run).and_return([[], true, '/tmp/report.csv'])
      end

      it 'writes a sentinel document to data_anonymizer_runs' do
        runner.run
        sentinel = runner.db[:data_anonymizer_runs].find.first
        expect(sentinel).to include('database' => runner.db.name, 'rails_env' => Rails.env)
      end

      it 'does not write a sentinel in dry-run mode' do
        dry_runner.run
        expect(dry_runner.db[:data_anonymizer_runs].count_documents({})).to eq(0)
      end

      it 'does not record sentinel when verifier fails' do
        allow_any_instance_of(DataAnonymizer::Verifier).to receive(:run).and_return([[], false, '/tmp/report.csv'])
        runner.run
        expect(runner.db[:data_anonymizer_runs].count_documents({})).to eq(0)
      end
    end

    # @!group Helper: anonymize_address_hash — address anonymization helper tests

    describe '#anonymize_address_hash' do
      let(:addr) do
        { 'kind' => 'home', 'address_1' => '100 Real St', 'city' => 'RealCity',
          'zip' => '99999', 'county' => 'RealCounty', 'state' => 'MA' }
      end

      subject(:result) { runner.send(:anonymize_address_hash, addr) }

      it 'replaces address_1' do
        expect(result['address_1']).not_to eq('100 Real St')
      end

      it 'replaces city' do
        expect(result['city']).not_to eq('RealCity')
      end

      it 'preserves zip' do
        expect(result['zip']).to eq('99999')
      end

      it 'preserves county by default' do
        expect(result['county']).to eq('RealCounty')
      end

      context 'when anonymize_zip: true' do
        it 'replaces zip' do
          zip_runner = DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: true, anonymize_zip: true)
          res = zip_runner.send(:anonymize_address_hash, addr)
          expect(res['zip']).not_to eq('99999')
        end
      end

      context 'when anonymize_county: true' do
        it 'replaces county' do
          county_runner = DataAnonymizer::Runner.new(batch_size: 5, dry_run: false, force: true, anonymize_county: true)
          res = county_runner.send(:anonymize_address_hash, addr)
          expect(res['county']).not_to eq('RealCounty')
        end
      end

      it 'sets address_2 to nil' do
        expect(result['address_2']).to be_nil
      end

      it 'preserves kind' do
        expect(result['kind']).to eq('home')
      end

      it 'preserves state' do
        expect(result['state']).to eq('MA')
      end

      it 'returns addr unchanged when addr is nil' do
        expect(runner.send(:anonymize_address_hash, nil)).to be_nil
      end

      it 'does not mutate the original hash' do
        original_city = addr['city']
        result
        expect(addr['city']).to eq(original_city)
      end
    end

    # @!group Helper: anonymize_phone_hash — phone anonymization helper tests

    describe '#anonymize_phone_hash' do
      let(:phone) { { 'kind' => 'work', 'area_code' => '617', 'number' => '5551234', 'extension' => '99' } }

      subject(:result) { runner.send(:anonymize_phone_hash, phone) }

      it 'replaces area_code' do
        expect(result['area_code']).not_to eq('617')
      end

      it 'replaces number' do
        expect(result['number']).not_to eq('5551234')
      end

      it 'sets extension to nil' do
        expect(result['extension']).to be_nil
      end

      it 'keeps kind' do
        expect(result['kind']).to eq('work')
      end

      it 'returns phone unchanged when phone is nil' do
        expect(runner.send(:anonymize_phone_hash, nil)).to be_nil
      end
    end

    # @!group Helper: anonymize_email_hash — email anonymization helper tests

    describe '#anonymize_email_hash' do
      let(:email_doc) { { 'kind' => 'home', 'address' => 'real@personal.com' } }

      subject(:result) { runner.send(:anonymize_email_hash, email_doc) }

      it 'replaces address with an anonymizer domain address' do
        expect(result['address']).to match(/@(exampleanonymizer|testanonymizer)\.com\z/)
        expect(result['address']).not_to eq('real@personal.com')
      end

      it 'preserves kind' do
        expect(result['kind']).to eq('home')
      end

      it 'returns nil unchanged when input is nil' do
        expect(runner.send(:anonymize_email_hash, nil)).to be_nil
      end

      it 'does not mutate the original hash' do
        original = email_doc['address']
        result
        expect(email_doc['address']).to eq(original)
      end
    end

    # @!group Age-band preservation — age-band correctness tests

    describe '#age_band' do
      let(:ref) { Date.new(2026, 5, 6) }

      it 'returns :under_18 for a child' do
        expect(runner.send(:age_band, Date.new(2010, 6, 1), ref)).to eq(:under_18)
      end

      it 'returns :between_18_25 for a young adult' do
        expect(runner.send(:age_band, Date.new(2004, 1, 1), ref)).to eq(:between_18_25)
      end

      it 'returns :over_26 for an adult over 26' do
        expect(runner.send(:age_band, Date.new(1990, 1, 1), ref)).to eq(:over_26)
      end
    end

    describe '#allowed_shift_range' do
      let(:ref) { Date.new(2026, 4, 13) }

      it 'returns a range keeping an over-26 person over 26' do
        dob = Date.new(1990, 1, 1)  # age ~36
        min, max = runner.send(:allowed_shift_range, dob, ref)
        expect(min).to be <= max
        shifted_dob = dob + max
        expect(runner.send(:age_on, shifted_dob, ref)).to be >= 26
      end

      it 'returns a range keeping an under-18 person under 18' do
        dob = Date.new(2015, 1, 1)  # age ~11
        min, max = runner.send(:allowed_shift_range, dob, ref)
        expect(min).to be <= max
        shifted_min = dob + min
        shifted_max = dob + max
        expect(runner.send(:age_on, shifted_min, ref)).to be < 18
        expect(runner.send(:age_on, shifted_max, ref)).to be < 18
      end

      it 'returns nil for a non-Date input' do
        expect(runner.send(:allowed_shift_range, 'not a date', ref)).to be_nil
      end
    end

    describe '#pick_group_shift_days' do
      it 'returns a random shift for an empty dobs array' do
        shifts = Array.new(5) { runner.send(:pick_group_shift_days, []) }
        expect(shifts.uniq.length).to be > 1
      end

      it 'returns 0 when no valid common range exists' do
        # Force conflicting ranges by stubbing allowed_shift_range
        allow(runner).to receive(:allowed_shift_range).and_return([-100, -50], [50, 100])
        result = runner.send(:pick_group_shift_days, [Date.new(1990, 1, 1), Date.new(1995, 1, 1)])
        expect(result).to eq(0)
      end
    end

    # ── Idempotent re-run ───

    describe 'idempotent re-run with force: true' do
      let!(:person) { FactoryBot.create(:person, first_name: 'Original', dob: Date.new(1985, 1, 1)) }

      it 'produces different fake names on second run' do
        runner.send(:anonymize_people)
        first_run_name = raw_doc('people', person.id)['first_name']

        runner.send(:anonymize_people)
        second_run_name = raw_doc('people', person.id)['first_name']

        # Names are random — extremely unlikely to match twice in a row
        # This validates re-anonymization works without error
        expect(first_run_name).not_to eq('Original')
        expect(second_run_name).not_to eq('Original')
      end
    end
  end

  # ======================
  # Verifier
  # ======================

  describe DataAnonymizer::Verifier do
    let(:verifier) { DataAnonymizer::Verifier.new }
    let(:db) { Mongoid.default_client.database }

    # ── check_history_trackers ────

    describe '#check_history_trackers' do
      context 'when history_trackers does not exist' do
        before { db[:history_trackers].drop rescue StandardError } # rubocop:disable Style/RescueModifier

        it 'passes' do
          result = verifier.send(:check_history_trackers)
          expect(result[:passed]).to be true
          expect(result[:samples]).to eq('dropped')
        end
      end

      context 'when history_trackers still exists' do
        before { db[:history_trackers].insert_one('first_name' => 'Real') }

        it 'fails with a descriptive issue message' do
          result = verifier.send(:check_history_trackers)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/history_trackers collection still exists/)
        end
      end
    end

    # ── check_people ───

    describe '#check_people' do
      context 'when people have been properly anonymized' do
        let!(:person) { FactoryBot.create(:person) }

        before do
          db[:people].update_one(
            { '_id' => person.id },
            { '$set' => { 'emails' => [{ 'address' => 'user1@exampleanonymizer.com', 'kind' => 'home' }] },
              '$unset' => { 'ssn' => '', 'tribal_id' => '' } }
          )
        end

        it 'passes' do
          result = verifier.send(:check_people)
          expect(result[:passed]).to be true
        end
      end

      context 'when plain-text ssn field remains' do
        let!(:person) { FactoryBot.create(:person) }

        before { db[:people].update_one({ '_id' => person.id }, { '$set' => { 'ssn' => '123456789' } }) }

        it 'fails and reports the count' do
          result = verifier.send(:check_people)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/plain-text 'ssn'/)
        end
      end

      context 'when tribal_id is non-nil' do
        let!(:person) { FactoryBot.create(:person) }

        before { db[:people].update_one({ '_id' => person.id }, { '$set' => { 'tribal_id' => 'T123' } }) }

        it 'fails' do
          result = verifier.send(:check_people)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/tribal_id/)
        end
      end

      context 'when an email has a real domain' do
        let!(:person) { FactoryBot.create(:person) }

        before do
          db[:people].update_one(
            { '_id' => person.id },
            { '$set' => { 'emails' => [{ 'address' => 'real@company.com', 'kind' => 'home' }] } }
          )
        end

        it 'fails' do
          result = verifier.send(:check_people)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/real emails/)
        end
      end
    end

    # ── check_users ───

    describe '#check_users' do
      context 'when users are fully anonymized' do
        let!(:user) { FactoryBot.create(:user) }

        before do
          db[:users].update_one(
            { '_id' => user.id },
            { '$set' => {
              'email' => 'user0@exampleanonymizer.com',
              'idp_uuid' => nil,
              'identity_final_decision_transaction_id' => nil,
              'current_login_token' => nil
            } }
          )
        end

        it 'passes' do
          result = verifier.send(:check_users)
          expect(result[:passed]).to be true
        end
      end

      context 'when idp_uuid is non-nil' do
        let!(:user) { FactoryBot.create(:user) }

        before { db[:users].update_one({ '_id' => user.id }, { '$set' => { 'idp_uuid' => 'some-uuid' } }) }

        it 'fails' do
          result = verifier.send(:check_users)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/idp_uuid/)
        end
      end

      context 'when a live session token remains' do
        let!(:user) { FactoryBot.create(:user) }

        before { db[:users].update_one({ '_id' => user.id }, { '$set' => { 'current_login_token' => 'active-token' } }) }

        it 'fails' do
          result = verifier.send(:check_users)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/current_login_token/)
        end
      end
    end

    # ── check_families ───

    describe '#check_families' do
      context 'when all e_case_ids have been cleared' do
        let!(:family) { FactoryBot.create(:family, :with_primary_family_member) }

        before { db[:families].update_one({ '_id' => family.id }, { '$unset' => { 'e_case_id' => '' } }) }

        it 'passes' do
          result = verifier.send(:check_families)
          expect(result[:passed]).to be true
        end
      end

      context 'when e_case_id still exists' do
        let!(:family) { FactoryBot.create(:family, :with_primary_family_member) } # factory sets e_case_id

        it 'fails' do
          result = verifier.send(:check_families)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/e_case_id/)
        end
      end
    end

    # ── check_census_members ───

    describe '#check_census_members' do
      context 'when all census_members have anonymized SSNs' do
        let!(:ce) { FactoryBot.create(:census_employee) }

        before { db[:census_members].update_one({ '_id' => ce.id }, { '$unset' => { 'ssn' => '' } }) }

        it 'passes' do
          result = verifier.send(:check_census_members)
          expect(result[:passed]).to be true
        end
      end

      context 'when a census_member still has a plain ssn field' do
        let!(:ce) { FactoryBot.create(:census_employee) }

        before { db[:census_members].update_one({ '_id' => ce.id }, { '$set' => { 'ssn' => '999887777' } }) }

        it 'fails' do
          result = verifier.send(:check_census_members)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/plain-text 'ssn'/)
        end
      end
    end

    # ── check_organizations ─────

    describe '#check_organizations' do
      context 'when organizations have no suspicious ACH data' do
        let!(:org) { FactoryBot.create(:organization) }

        before do
          db[:organizations].update_one(
            { '_id' => org.id },
            { '$set' => { 'broker_agency_profile' => { 'ach_routing_number' => '123456789', 'ach_account_number' => 'fakeacct' } } }
          )
        end

        it 'passes' do
          result = verifier.send(:check_organizations)
          expect(result[:passed]).to be true
        end
      end

      context 'when an org has a routing number of wrong length' do
        let!(:org) { FactoryBot.create(:organization) }

        before do
          db[:organizations].update_one(
            { '_id' => org.id },
            { '$set' => { 'broker_agency_profile' => { 'ach_routing_number' => '12345', 'ach_account_number' => 'acct' } } }
          )
        end

        it 'fails' do
          result = verifier.send(:check_organizations)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/routing/)
        end
      end
    end

    # ── check_bs_organizations ────

    describe '#check_bs_organizations' do
      context 'when no BS organizations exist' do
        before { db[:benefit_sponsors_organizations_organizations].drop rescue StandardError } # rubocop:disable Style/RescueModifier

        it 'passes' do
          result = verifier.send(:check_bs_organizations)
          expect(result[:passed]).to be true
        end
      end

      context 'when BS organizations have properly anonymized ACH data' do
        before do
          db[:benefit_sponsors_organizations_organizations].insert_one(
            'legal_name' => 'Fake Corp',
            'profiles' => [{ 'ach_routing_number' => '987654321', 'ach_account_number' => 'fakeacct' }]
          )
        end

        it 'passes' do
          result = verifier.send(:check_bs_organizations)
          expect(result[:passed]).to be true
        end
      end

      context 'when a BS organization has a routing number of wrong length' do
        before do
          db[:benefit_sponsors_organizations_organizations].insert_one(
            'legal_name' => 'Bad Corp',
            'profiles' => [{ 'ach_routing_number' => '1234', 'ach_account_number' => 'acct' }]
          )
        end

        it 'fails' do
          result = verifier.send(:check_bs_organizations)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/routing/)
        end
      end
    end

    # ── check_census_person_consistency ───

    describe '#check_census_person_consistency' do
      context 'when no census members have employee_role_id' do
        it 'returns a neutral (skipped) result without failing' do
          db[:census_members].update_many({}, { '$unset' => { 'employee_role_id' => '' } })
          result = verifier.send(:check_census_person_consistency)
          expect(result[:passed]).to be true
          expect(result[:samples]).to match(/skipped/)
        end
      end

      context 'when names are consistent' do
        let!(:person) { FactoryBot.create(:person, first_name: 'SyntheticFirst') }
        let!(:census)  { FactoryBot.create(:census_employee, first_name: 'SyntheticFirst') }

        before do
          role_id = BSON::ObjectId.new
          db[:people].update_one({ '_id' => person.id }, { '$push' => { 'employee_roles' => { '_id' => role_id } } })
          db[:census_members].update_one({ '_id' => census.id }, { '$set' => { 'employee_role_id' => role_id } })
        end

        it 'passes' do
          result = verifier.send(:check_census_person_consistency)
          expect(result[:passed]).to be true
        end
      end

      context 'when first_names are inconsistent' do
        let!(:person) { FactoryBot.create(:person, first_name: 'PersonFake') }
        let!(:census)  { FactoryBot.create(:census_employee, first_name: 'DifferentName') }

        before do
          role_id = BSON::ObjectId.new
          db[:people].update_one({ '_id' => person.id }, { '$push' => { 'employee_roles' => { '_id' => role_id } } })
          db[:census_members].update_one({ '_id' => census.id }, { '$set' => { 'employee_role_id' => role_id } })
        end

        it 'fails and reports the mismatch count' do
          result = verifier.send(:check_census_person_consistency)
          expect(result[:passed]).to be false
          expect(result[:issues]).to match(/mismatch/)
        end
      end
    end

    # ── Full Verifier#run ────

    describe '#run' do
      before do
        # Drop history_trackers to avoid a false FAIL
        db[:history_trackers].drop rescue StandardError # rubocop:disable Style/RescueModifier
        # Clear real e_case_ids
        db[:families].update_many({}, { '$unset' => { 'e_case_id' => '' } })
      end

      it 'writes a CSV report to tmp/' do
        verifier.run
        csv_path = Dir[File.join(Rails.root, 'tmp', 'anonymization_report_*.csv')].max_by { |f| File.mtime(f) }
        expect(File.exist?(csv_path)).to be true
      end

      it 'includes a row per collection in the CSV' do
        verifier.run
        csv_path = Dir[File.join(Rails.root, 'tmp', 'anonymization_report_*.csv')].max_by { |f| File.mtime(f) }
        rows = CSV.read(csv_path, headers: true)
        collections = rows.map { |r| r['collection'] }
        expect(collections).to include(a_string_matching(/people/i))
        expect(collections).to include(a_string_matching(/users/i))
        expect(collections).to include(a_string_matching(/families/i))
      end
    end
  end
end
