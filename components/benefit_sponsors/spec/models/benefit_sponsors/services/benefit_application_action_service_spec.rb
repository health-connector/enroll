require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe ::BenefitSponsors::Services::BenefitApplicationActionService, type: :model, :dbclean => :after_each do

    subject { BenefitSponsors::Services::BenefitApplicationActionService }

    include_context "setup benefit market with market catalogs and product packages"

    include_context "setup initial benefit application" do
      let(:current_effective_date) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
    end

    describe '.terminate_application' do

      let(:past_end_on)  { TimeKeeper.date_of_record.prev_month.end_of_month }
      let(:future_end_on)  { TimeKeeper.date_of_record.next_month.end_of_month }
      let(:termination_kind) { "voluntary" }
      let(:termination_reason) { "Company went out of business/bankrupt" }

      context 'when terminated with future date' do

        before do
          subject.new(initial_application, {end_on: future_end_on, termination_kind: termination_kind, termination_reason: termination_reason, transmit_to_carrier: false}).terminate_application
          initial_application.reload
        end

        it 'should move benefit application to termination pending' do
          expect(initial_application.aasm_state).to eq :termination_pending
        end
      end

      context 'when terminated with past date' do

        before do
          subject.new(initial_application, {end_on: past_end_on, termination_kind: termination_kind, termination_reason: termination_reason,transmit_to_carrier: false}).terminate_application
          initial_application.reload
        end

        it 'should terminate benefit application immediately' do
          expect(initial_application.aasm_state).to eq :terminated
        end
      end

      context "when employer has renewing application" do

        let!(:renewal_benefit_sponsor_catalog) { benefit_sponsorship.benefit_sponsor_catalog_for(current_effective_date.next_year) }
        let!(:renewal_application)             { initial_application.renew }

        before do
          subject.new(initial_application, {end_on: past_end_on, termination_kind: termination_kind, termination_reason: termination_reason, transmit_to_carrier: false}).terminate_application
          renewal_application.reload
        end

        it 'should cancel renewal application' do
          expect(renewal_application.aasm_state).to eq :canceled
        end
      end

      context "when employer has renewing application and initial application termination failed" do
        let!(:renewal_benefit_sponsor_catalog) { benefit_sponsorship.benefit_sponsor_catalog_for(current_effective_date.next_year) }
        let!(:renewal_application) do
          r_app = initial_application.renew
          r_app.save!
          r_app
        end
        let(:end_on_before_start_on) { initial_application.start_on.to_date - 1.day }

        before do
          subject.new(initial_application, {end_on: end_on_before_start_on, termination_kind: termination_kind, termination_reason: termination_reason, transmit_to_carrier: false}).terminate_application
          initial_application.reload
          renewal_application.reload
        end

        it 'should not cancel renewal application' do
          expect(initial_application.aasm_state).to eq :active
          expect(renewal_application.aasm_state).not_to eq :canceled
        end
      end
    end

    describe 'cancel_application' do
      let(:current_effective_date)  { (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year }

      context "cancelling effectuated application" do
        before do
          subject.new(initial_application, {transmit_to_carrier: false}).cancel_application
          initial_application.reload
        end

        it "should cancel benefit application" do
          expect(initial_application.aasm_state).to eq :retroactive_canceled
        end
      end

      context "cancelling non effectuated application" do
        before do
          initial_application.update_attributes(aasm_state: :enrollment_ineligible)
          initial_application.benefit_application_items.create!(state: :enrollment_ineligible, sequence_id: 1, effective_period: effective_period)
          subject.new(initial_application, {transmit_to_carrier: false}).cancel_application
          initial_application.reload
        end

        it "should cancel benefit application" do
          expect(initial_application.aasm_state).to eq :canceled
        end
      end
    end
  end
end
