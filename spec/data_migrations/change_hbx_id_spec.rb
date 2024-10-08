# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'change_hbx_id')

describe ChangeHbxId do
  let(:given_task_name) { 'change_hbx_id' }
  subject { ChangeHbxId.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'changing person hbx id' do
    let(:person) { FactoryBot.create(:person)}

    it 'should change person hbx id ' do
      ClimateControl.modify person_hbx_id: person.hbx_id, new_hbx_id: '34588973' do
        subject.migrate
        person.reload
        expect(person.hbx_id).to eq '34588973'
      end
    end
  end
end
