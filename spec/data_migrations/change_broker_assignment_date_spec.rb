# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'change_broker_assignment_date')

describe ChangeBrokerAssignmentDate, dbclean: :after_each do

  let(:given_task_name) { 'change_broker_assignment_date' }
  subject { ChangeBrokerAssignmentDate.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  let!(:broker_role) { FactoryBot.create(:broker_role, aasm_state: 'active') }
  let!(:broker_agency_profile) { FactoryBot.create(:broker_agency_profile, aasm_state: 'is_approved', primary_broker_role: broker_role)}
  let!(:person) { FactoryBot.create(:person)}
  let!(:family) { FactoryBot.create(:family, :with_primary_family_member,person: person) }
  let!(:broker_agency_account) {FactoryBot.create(:broker_agency_account,broker_agency_profile_id: broker_agency_profile.id,writing_agent_id: broker_role.id, start_on: TimeKeeper.date_of_record)}

  before :each do
    allow_any_instance_of(Family).to receive(:current_broker_agency).and_return(broker_agency_account)
  end

  it 'should have a broker agency' do
    ClimateControl.modify person_hbx_id: person.hbx_id, new_date: (TimeKeeper.date_of_record + 44.days).to_s do
      subject.migrate
      person.primary_family.reload
      expect(person.primary_family.current_broker_agency.start_on).to eq(TimeKeeper.date_of_record + 44.days)
    end
  end
end
