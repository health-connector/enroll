# frozen_string_literal: true

require 'rails_helper'
require 'rake'

require File.join(Rails.root, 'app', 'data_migrations', 'add_primary_family')

describe AddPrimaryFamily, dbclean: :after_each do
  let(:given_task_name) { 'add_primary_family' }
  subject { AddPrimaryFamily.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'Add Primary Family to the Person' do
    let(:person) { FactoryBot.create(:person)}
    let(:family) { FactoryBot.create(:family, :with_primary_family_member, :person => person) }

    it 'should create a family with person as primary applicant' do
      ClimateControl.modify(dep_hbx_id: person.hbx_id) do
        subject.migrate
        expect(person.primary_family.primary_applicant.person).to eq person
      end
    end
  end
end
