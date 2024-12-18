# frozen_string_literal: true

require "rails_helper"
if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
  require File.join(Rails.root, "app", "data_migrations", "update_aptc_dental_enr")


  describe UpdateAptcDentalEnr, dbclean: :after_each do
    let(:given_task_name) { "update_aptc_dental_enr" }
    subject { UpdateAptcDentalEnr.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "updating the applied aptc amount for a Dental Plan" do
      let(:person) { FactoryBot.create(:person, :with_family) }
      let(:family) { person.primary_family }
      let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, :coverage_kind => "dental", applied_aptc_amount: 100.00, household: family.active_household)}

      it "should update aptc amount only for dental plan" do
        ClimateControl.modify :hbx_id => person.hbx_id.to_s, :enr_hbx_id => hbx_enrollment.hbx_id.to_s do
          expect(family.active_household.hbx_enrollments).to include hbx_enrollment
          expect(hbx_enrollment.applied_aptc_amount.to_f).to eq 100.00
          subject.migrate
          hbx_enrollment.reload
          expect(hbx_enrollment.applied_aptc_amount.to_f).to eq 0.00
        end
      end
    end

    describe "should not update for a Health Plan" do
      let(:person) { FactoryBot.create(:person, :with_family) }
      let(:family) { person.primary_family }
      let(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, :coverage_kind => "health", applied_aptc_amount: 100.00, household: family.active_household)}

      it "should not update aptc amount if it is a health plan" do
        ClimateControl.modify :hbx_id => person.hbx_id.to_s, :enr_hbx_id => hbx_enrollment.hbx_id.to_s do
          expect(hbx_enrollment.applied_aptc_amount.to_f).to eq 100.00
          subject.migrate
          hbx_enrollment.reload
          expect(hbx_enrollment.applied_aptc_amount.to_f).not_to eq 0.00
        end
      end
    end
  end
end
