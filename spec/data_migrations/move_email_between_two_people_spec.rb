# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'move_email_between_two_people')

describe MoveEmailBetweenTwoPeople do
  let(:given_task_name) { 'move_email_between_two_people' }
  subject { MoveEmailBetweenTwoPeople.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'move email between two people' do
    let!(:person1) { FactoryBot.create(:person)}
    let!(:person2) { FactoryBot.create(:person)}

    it 'add emails to person 2' do
      ClimateControl.modify from_hbx_id: person1.hbx_id, to_hbx_id: person2.hbx_id do
        person1_email_before = person1.emails.size
        person2_email_before = person2.emails.size
        subject.migrate
        person1.reload
        person2.reload
        expect(person2.emails.size).to eq person1_email_before + person2_email_before
        expect(person1.emails.size).to eq 0
      end
    end
  end
end
