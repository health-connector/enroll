# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
RSpec.describe BenefitSponsors::Operations::BenefitApplications::Reinstate, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees"

  context 'with invalid params' do

    context 'missing benefit application' do
      let(:params) do
        { transmit_to_carrier: true, reinstate_on: TimeKeeper.date_of_record.beginning_of_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure?).to eq true
      end
    end

    context 'missing transmit_to_carrier' do
      let(:params) do
        { benefit_application: initial_application, reinstate_on: TimeKeeper.date_of_record.beginning_of_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure?).to eq true
      end
    end

    context 'missing reinstate_on' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: initial_application }
      end

      it 'returns failure' do
        expect(subject.call(params).failure?).to eq true
      end
    end

    context 'invalid benefit application' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: double, reinstate_on: TimeKeeper.date_of_record.beginning_of_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure?).to eq true
      end
    end
  end

  context 'with valid params' do
    let(:benefit_application) do
      effective_period = initial_application.effective_period
      updated_dates = effective_period.min..(TimeKeeper.date_of_record.beginning_of_month - 1.day)
      initial_application.benefit_application_items.create(
        sequence_id: 1,
        effective_period: updated_dates,
        state: :terminated
      )
      initial_application.terminate_enrollment!
      initial_application.reload
    end
    let(:reinstate_on) { benefit_application.end_on + 1.day }

    let(:params) do
      { transmit_to_carrier: true, benefit_application: benefit_application, reinstate_on: reinstate_on }
    end

    context 'reinstate benefit application' do
      it 'should reinstate benefit application' do
        expect(benefit_application.aasm_state).to eq :terminated
        subject.call(params)
        item = benefit_application.reload.latest_benefit_application_item

        expect(benefit_application.aasm_state).to eq :reinstated
        expect(item.effective_period.min).to eq reinstate_on
        expect(item.state).to eq :reinstate
        expect(item.action_kind).to eq 'reinstate'
      end
    end

    context 'reinstate benefit application with census employees' do
      it 'should reinstate benefit group assignments' do
        bga = census_employees.first.benefit_group_assignments[0]
        expect(bga.end_on).not_to eq nil
        subject.call(params)

        expect(benefit_application.aasm_state).to eq :reinstated
        expect(bga.reload.end_on).to eq nil
      end
    end
  end
end
