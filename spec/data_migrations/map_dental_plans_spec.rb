# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, 'app', 'data_migrations', 'map_dental_plans')

describe MapDentalPlans, dbclean: :after_each do
  let(:given_task_name) { 'map_dental_plans' }
  subject { MapDentalPlans.new(given_task_name, double(:current_scope => nil)) }

  describe 'given a task name' do
    it 'has the given task name' do
      expect(subject.name).to eql given_task_name
    end
  end

  describe 'update the previous year renewal plan_id' do

    let(:previous_year_plan){ FactoryBot.create(:plan, active_year: '2016', hios_id: '14171AB0010203', coverage_kind: 'dental', dental_level: 'low', market: 'shop') }
    let(:current_year_plan){ FactoryBot.create(:plan, active_year: '2017', hios_id: '14171AB0010203', coverage_kind: 'dental', dental_level: 'low', market: 'shop') }

    it 'when the plan is present' do
      ClimateControl.modify previous_year: '2016', current_year: '2017' do
        current_year_plan.valid?
        previous_year_plan.valid?
        subject.migrate
        previous_year_plan.reload
        expect(previous_year_plan.renewal_plan).to eq current_year_plan
        expect(previous_year_plan.renewal_plan_id.to_s).to eq current_year_plan.id.to_s
      end
    end
  end
end
