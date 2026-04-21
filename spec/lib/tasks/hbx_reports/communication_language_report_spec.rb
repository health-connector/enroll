# frozen_string_literal: true

require 'rails_helper'
require 'csv'

describe 'Communication language summary report', :dbclean => :after_each do
  let(:task_name)   { 'reports:communication:communication_language_summary' }
  let(:date_suffix) { TimeKeeper.date_of_record.strftime('%m_%d_%Y') }
  let(:file_name)   { "#{Rails.root}/public/communication_language_summary_#{date_suffix}.csv" }

  before do
    load File.expand_path("#{Rails.root}/lib/tasks/hbx_reports/communication_language_report.rake", __FILE__)
    Rake::Task.define_task(:environment)
    Rake::Task[task_name].reenable
  end

  after(:all) do
    date_suffix = TimeKeeper.date_of_record.strftime('%m_%d_%Y')
    FileUtils.rm_f("#{Rails.root}/public/communication_language_summary_#{date_suffix}.csv")
  end

  describe 'CSV file structure' do
    before { Rake::Task[task_name].invoke }

    it 'creates the output file' do
      expect(File.exist?(file_name)).to be true
    end

    it 'includes a Preference section header row' do
      expect(CSV.read(file_name)).to include(['EE Communication Preference', ''])
    end

    it 'includes a Language section header row' do
      expect(CSV.read(file_name)).to include(['EE Language Preference', ''])
    end

    it 'includes a cross-tab header row with all language columns' do
      expect(CSV.read(file_name)).to include(
        ['EE Preference and Language', 'English', 'Spanish', 'Amharic', 'Other or Blank']
      )
    end

    it 'emits a count row for each preference bucket' do
      data = CSV.read(file_name)
      %w[Paper Electronic].each do |label|
        expect(data.any? { |row| row.first == label && row.size == 2 }).to be true
      end
      expect(data.any? { |row| row.first == 'Paper and Electronic' && row.size == 2 }).to be true
    end

    it 'emits a count row for each language bucket' do
      data = CSV.read(file_name)
      %w[English Spanish Amharic].each do |label|
        expect(data.any? { |row| row.first == label && row.size == 2 }).to be true
      end
    end
  end

  describe 'employer counting' do
    context 'with multiple active ERs having different contact methods' do
      let!(:org_one)   { FactoryBot.create(:employer) }
      let!(:org_two)   { FactoryBot.create(:employer) }
      let!(:org_three) { FactoryBot.create(:employer) }

      before do
        org_one.employer_profile.update_attributes(contact_method: 'Only Electronic communications')
        org_two.employer_profile.update_attributes(contact_method: 'Only Paper communication')
        org_three.employer_profile.update_attributes(contact_method: 'Paper and Electronic communications')
        Rake::Task[task_name].invoke
      end

      it 'counts ER preferences correctly' do
        data = CSV.read(file_name)
        er_index = data.index { |r| r.first == 'ER Communication Preference' && r[1] == '' }
        expect(er_index).not_to be_nil

        # ER rows are located immediately after the ER header
        paper_row      = data[er_index + 1]
        electronic_row = data[er_index + 2]
        pae_row        = data[er_index + 3]

        expect(paper_row).to eq ['Paper', '1']
        expect(electronic_row).to eq ['Electronic', '1']
        expect(pae_row).to eq ['Paper and Electronic', '1']

        total_row = data[er_index + 1 + 4]
        expect(total_row).to eq ['Total', '3']
      end
    end
  end

  describe 'employee counting' do
    # employer_profile starts with aasm_state "applicant",
    # which is in EmployerProfile::ACTIVE_STATES, so has_active_state? => true.
    let(:employer_profile) { FactoryBot.create(:employer_profile) }

    # census_employee with aasm_state: 'eligible' satisfies
    # CensusEmployee::EMPLOYMENT_ACTIVE_STATES and therefore is_active? => true.
    let(:active_census_employee) do
      FactoryBot.create(:census_employee, aasm_state: 'eligible', employer_profile: employer_profile)
    end

    context 'with a single active EE using Paper and Electronic / Spanish' do
      let!(:person) { FactoryBot.create(:person, :with_ssn) }
      let!(:employee_role) do
        FactoryBot.create(
          :employee_role,
          person: person,
          employer_profile: employer_profile,
          census_employee_id: active_census_employee.id,
          hired_on: active_census_employee.hired_on,
          contact_method: 'Paper and Electronic communications',
          language_preference: 'Spanish'
        )
      end

      before { Rake::Task[task_name].invoke }

      it 'sets the Paper and Electronic preference count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Paper and Electronic' && r.size == 2 }
        expect(row).to eq ['Paper and Electronic', '1']
      end

      it 'sets the Spanish language count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Spanish' && r.size == 2 }
        expect(row).to eq ['Spanish', '1']
      end

      it 'sets the cross-tab Paper and Electronic / Spanish cell to 1' do
        # Cross-tab rows have 5 columns: pref, English(1), Spanish(2), Amharic(3), Other(4)
        row = CSV.read(file_name).find { |r| r.first == 'Paper and Electronic' && r.size == 5 }
        expect(row[2]).to eq '1'
      end

      it 'sets the total to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Total' }
        expect(row).to eq ['Total', '1']
      end
    end

    context 'with a single active EE using Only Electronic / English' do
      let!(:person) { FactoryBot.create(:person, :with_ssn) }
      let!(:employee_role) do
        FactoryBot.create(
          :employee_role,
          person: person,
          employer_profile: employer_profile,
          census_employee_id: active_census_employee.id,
          hired_on: active_census_employee.hired_on,
          contact_method: 'Only Electronic communications',
          language_preference: 'English'
        )
      end

      before { Rake::Task[task_name].invoke }

      it 'sets the Electronic preference count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Electronic' && r.size == 2 }
        expect(row).to eq ['Electronic', '1']
      end

      it 'sets the English language count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'English' && r.size == 2 }
        expect(row).to eq ['English', '1']
      end
    end

    context 'with a single active EE using Only Paper / Amharic' do
      let!(:person) { FactoryBot.create(:person, :with_ssn) }
      let!(:employee_role) do
        FactoryBot.create(
          :employee_role,
          person: person,
          employer_profile: employer_profile,
          census_employee_id: active_census_employee.id,
          hired_on: active_census_employee.hired_on,
          contact_method: 'Only Paper communication',
          language_preference: 'Amharic'
        )
      end

      before { Rake::Task[task_name].invoke }

      it 'sets the Paper preference count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Paper' && r.size == 2 }
        expect(row).to eq ['Paper', '1']
      end

      it 'sets the Amharic language count to 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Amharic' && r.size == 2 }
        expect(row).to eq ['Amharic', '1']
      end
    end

    context 'when an EE has a terminated census_employee' do
      let(:terminated_census_employee) do
        FactoryBot.create(:census_employee, aasm_state: 'eligible', employer_profile: employer_profile)
      end

      let!(:person) { FactoryBot.create(:person, :with_ssn) }
      let!(:employee_role) do
        FactoryBot.create(
          :employee_role,
          person: person,
          employer_profile: employer_profile,
          census_employee_id: terminated_census_employee.id,
          hired_on: terminated_census_employee.hired_on,
          contact_method: 'Paper and Electronic communications',
          language_preference: 'English'
        )
      end

      before do
        allow_any_instance_of(CensusEmployee).to receive(:is_active?).and_return(false)
        Rake::Task[task_name].invoke
      end

      it 'excludes the terminated EE from the total count' do
        row = CSV.read(file_name).find { |r| r.first == 'Total' }
        expect(row).to eq ['Total', '0']
      end

      it 'does not increment any preference count' do
        data = CSV.read(file_name)
        %w[Paper Electronic].each do |label|
          row = data.find { |r| r.first == label && r.size == 2 }
          expect(row.last).to eq '0'
        end
        pae_row = data.find { |r| r.first == 'Paper and Electronic' && r.size == 2 }
        expect(pae_row.last).to eq '0'
      end
    end

    context 'with multiple active EEs having different preference and language combinations' do
      let(:active_census_employee_2) do
        FactoryBot.create(:census_employee, aasm_state: 'eligible', employer_profile: employer_profile)
      end

      let!(:person_one) { FactoryBot.create(:person, :with_ssn) }
      let!(:person_two) { FactoryBot.create(:person, :with_ssn) }
      let!(:employee_role_one) do
        FactoryBot.create(
          :employee_role,
          person: person_one,
          employer_profile: employer_profile,
          census_employee_id: active_census_employee.id,
          hired_on: active_census_employee.hired_on,
          contact_method: 'Paper and Electronic communications',
          language_preference: 'English'
        )
      end
      let!(:employee_role_two) do
        FactoryBot.create(
          :employee_role,
          person: person_two,
          employer_profile: employer_profile,
          census_employee_id: active_census_employee_2.id,
          hired_on: active_census_employee_2.hired_on,
          contact_method: 'Only Paper communication',
          language_preference: 'Spanish'
        )
      end

      before { Rake::Task[task_name].invoke }

      it 'sets the total to 2' do
        row = CSV.read(file_name).find { |r| r.first == 'Total' }
        expect(row).to eq ['Total', '2']
      end

      it 'counts Paper and Electronic as 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Paper and Electronic' && r.size == 2 }
        expect(row).to eq ['Paper and Electronic', '1']
      end

      it 'counts Paper as 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Paper' && r.size == 2 }
        expect(row).to eq ['Paper', '1']
      end

      it 'counts English as 1' do
        row = CSV.read(file_name).find { |r| r.first == 'English' && r.size == 2 }
        expect(row).to eq ['English', '1']
      end

      it 'counts Spanish as 1' do
        row = CSV.read(file_name).find { |r| r.first == 'Spanish' && r.size == 2 }
        expect(row).to eq ['Spanish', '1']
      end

      it 'records the correct cross-tab cells' do
        data = CSV.read(file_name)
        pae_row = data.find { |r| r.first == 'Paper and Electronic' && r.size == 5 }
        paper_row = data.find { |r| r.first == 'Paper' && r.size == 5 }
        # Paper and Electronic / English => index 1
        expect(pae_row[1]).to eq '1'
        # Paper / Spanish => index 2
        expect(paper_row[2]).to eq '1'
      end
    end
  end

  describe '#communication_preference_bucket' do
    it 'buckets the default employee_role value as Paper and Electronic' do
      expect(communication_preference_bucket('Paper and Electronic communications')).to eq 'Paper and Electronic'
    end

    it 'buckets Only Electronic communications as Electronic' do
      expect(communication_preference_bucket('Only Electronic communications')).to eq 'Electronic'
    end

    it 'buckets Only Paper communication as Paper' do
      expect(communication_preference_bucket('Only Paper communication')).to eq 'Paper'
    end

    it 'buckets nil as Other or Blank' do
      expect(communication_preference_bucket(nil)).to eq 'Other or Blank'
    end

    it 'buckets an empty string as Other or Blank' do
      expect(communication_preference_bucket('')).to eq 'Other or Blank'
    end
  end

  describe '#language_preference_bucket' do
    it 'buckets English as English' do
      expect(language_preference_bucket('English')).to eq 'English'
    end

    it 'buckets Spanish as Spanish' do
      expect(language_preference_bucket('Spanish')).to eq 'Spanish'
    end

    it 'buckets Amharic as Amharic' do
      expect(language_preference_bucket('Amharic')).to eq 'Amharic'
    end

    it 'buckets the locale code en as English' do
      expect(language_preference_bucket('en')).to eq 'English'
    end

    it 'buckets the locale code es as Spanish' do
      expect(language_preference_bucket('es')).to eq 'Spanish'
    end

    it 'buckets the locale code am as Amharic' do
      expect(language_preference_bucket('am')).to eq 'Amharic'
    end

    it 'buckets an unrecognised value as Other or Blank' do
      expect(language_preference_bucket('French')).to eq 'Other or Blank'
    end

    it 'buckets nil as Other or Blank' do
      expect(language_preference_bucket(nil)).to eq 'Other or Blank'
    end
  end
end
