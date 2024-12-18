# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'delink_broker')

describe DelinkBroker do
  let(:given_task_name) { 'delink_broker' }
  let(:person) { FactoryBot.create(:person,:with_broker_role)}
  let(:organization1) {FactoryBot.create(:organization)}
  let(:organization) {FactoryBot.create(:organization)}
  let(:employer_profile) { FactoryBot.create(:employer_profile, organization: organization)}
  let(:broker_agency_profile) {FactoryBot.create(:broker_agency_profile, organization: organization1)}
  let(:broker_agency_account) {FactoryBot.create(:broker_agency_account, broker_agency_profile: broker_agency_profile, writing_agent_id: person.broker_role.id, is_active: true, employer_profile: employer_profile)}
  subject { DelinkBroker.new(given_task_name, double(:current_scope => nil)) }

  before(:each) do
    employer_profile.broker_agency_accounts << broker_agency_account
  end

  it 'Should update the person broker_role id with with new broker_agency' do
    ClimateControl.modify person_hbx_id: person.hbx_id, legal_name: 'legal_name', fein: 'fein', organization_ids_to_move: employer_profile.organization.id.to_s do
      old_broker_agency_profile_id = person.broker_role.broker_agency_profile_id.to_s
      subject.migrate
      person.reload
      expect(old_broker_agency_profile_id.to_s).not_to eq(person.broker_role.broker_agency_profile_id.to_s)
    end
  end
end
