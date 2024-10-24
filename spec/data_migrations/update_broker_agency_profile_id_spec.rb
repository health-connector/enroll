# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'update_broker_agency_profile_id')

describe UpdateBrokerAgencyProfileId, dbclean: :after_each do

  let(:given_task_name) { 'update_broker_agency_profile_id' }
  subject { UpdateBrokerAgencyProfileId.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'update benefit agency profile' do
    let(:person) { FactoryBot.create(:person, user: user) }
    let(:user) { FactoryBot.create(:user) }
    let(:broker_role) { FactoryBot.create(:broker_role, aasm_state: 'active') }
    let(:broker_agency) { FactoryBot.create(:broker_agency, legal_name: 'agencytwo') }
    let(:broker_agency_profile) { FactoryBot.create(:broker_agency_profile) }

    before(:each) do
      broker_agency.broker_agency_profile.update_attributes(primary_broker_role: broker_role)
      broker_role.update_attributes(broker_agency_profile: broker_agency.broker_agency_profile)
      broker_agency.broker_agency_profile.approve!
      @broker_agency_staff_role = FactoryBot.create(:broker_agency_staff_role, broker_agency_profile_id: broker_agency_profile.id,person: person)
      allow(Person).to receive(:where).and_return([person])
      allow(person).to receive(:broker_role).and_return(broker_role)
    end

    context 'broker_agency_profile', dbclean: :after_each do
      it 'should update broker_agency_profile id' do
        ClimateControl.modify hbx_id: person.hbx_id do
          subject.migrate
          expect(@broker_agency_staff_role.broker_agency_profile_id).to eq(person.broker_role.broker_agency_profile.id)
        end
      end
    end
  end
end
