# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Datatables::UserAccountsTable, dbclean: :after_each do
  subject(:table) { described_class.new }

  describe '#columns' do
    it 'mirrors the legacy UserAccountDatatable column order and labels' do
      expect(table.columns.map { |col| col[:name] }).to eq(
        %w[name ssn dob hbx_id email status role_type actions]
      )
      expect(table.columns.map { |col| col[:label] }).to eq(
        ['USERNAME', 'SSN', 'DOB', 'HBX ID', 'USER EMAIL', 'Status', 'Role Type', 'Actions']
      )
    end

    it 'marks only the username column sortable' do
      expect(table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }).to eq(['name'])
    end

    it 'types hbx_id as integer for the col-integer class' do
      expect(table.columns.find { |col| col[:name] == 'hbx_id' }[:type]).to eq(:integer)
    end
  end

  describe '#collection' do
    it 'wraps the filter attributes in the legacy UserDatatableQuery' do
      collection = table.collection(users: 'all_broker_roles', lock_unlock: 'locked')
      expect(collection).to be_a(Queries::UserDatatableQuery)
      expect(collection.custom_attributes).to eq(users: 'all_broker_roles', lock_unlock: 'locked')
    end
  end

  describe '#filters' do
    it 'reproduces the legacy nested filter definition' do
      expect(table.filters[:top_scope]).to eq(:users)
      expect(table.filters[:users].map { |filter| filter[:scope] }).to eq(
        %w[all all_employee_roles all_employer_staff_roles all_broker_roles]
      )
      expect(table.filters[:users]).to all(include(subfilter: :lock_unlock))
      expect(table.filters[:lock_unlock].map { |filter| filter[:scope] }).to eq(%w[locked unlocked])
    end
  end

  describe '#status' do
    it 'is Unlocked when neither locked_at nor unlock_token is set' do
      expect(table.status(User.new)).to eq('Unlocked')
    end

    it 'is Locked when locked_at is set' do
      expect(table.status(User.new(locked_at: Time.now))).to eq('Locked')
    end
  end

  describe 'csv export' do
    let(:person) { FactoryBot.create(:person, hbx_id: '12345', dob: Date.new(1980, 6, 1), ssn: '789001234') }
    let(:user) { FactoryBot.create(:user, person: person, oim_id: 'csv_export_user', email: 'csv@example.com', roles: ['employee']) }

    it 'excludes the actions column from the headers' do
      expect(table.csv_headers).to eq(['USERNAME', 'SSN', 'DOB', 'HBX ID', 'USER EMAIL', 'Status', 'Role Type'])
    end

    it 'renders the same plain-text values the table cells show' do
      expect(table.csv_row(user)).to eq(
        ['csv_export_user', '***-**-1234', '06/01/1980', '12345', 'csv@example.com', 'Unlocked', 'employee']
      )
    end

    it 'leaves person-derived cells blank when the user has no person' do
      orphan = FactoryBot.create(:user, oim_id: 'csv_no_person', email: 'no-person@example.com', roles: [])
      expect(table.csv_row(orphan)).to eq(
        ['csv_no_person', nil, nil, nil, 'no-person@example.com', 'Unlocked', '']
      )
    end
  end
end
