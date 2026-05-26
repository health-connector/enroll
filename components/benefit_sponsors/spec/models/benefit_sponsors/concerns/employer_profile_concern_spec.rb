# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe Concerns::EmployerProfileConcern, type: :model, dbclean: :after_each do
    describe "#enrollments_for_billing" do
      include_context "setup benefit market with market catalogs and product packages"

      let(:aasm_state) { :enrollment_eligible }

      include_context "setup initial benefit application"

      let(:person) { FactoryBot.create(:person, :with_family) }
      let(:family) { person.primary_family }
      let(:benefit_package) { initial_application.benefit_packages.first }
      let(:profile) { abc_profile }

      let!(:health_enrollment) do
        FactoryBot.create(
          :hbx_enrollment,
          household: family.active_household,
          coverage_kind: 'health',
          effective_on: initial_application.start_on,
          aasm_state: 'coverage_selected',
          sponsored_benefit_package_id: benefit_package.id,
          benefit_sponsorship_id: initial_application.benefit_sponsorship.id
        )
      end

      context "when enrollment has sponsored_benefit_package_id set" do
        it "returns the enrollment for billing" do
          expect(profile.enrollments_for_billing).to include(health_enrollment)
        end

        it "does not return enrollments without a matching sponsored_benefit_package_id" do
          other_enrollment = FactoryBot.create(
            :hbx_enrollment,
            household: family.active_household,
            coverage_kind: 'health',
            effective_on: initial_application.start_on,
            aasm_state: 'coverage_selected'
          )
          expect(profile.enrollments_for_billing).not_to include(other_enrollment)
        end
      end

      context "after an enrollment change to a different carrier" do
        let!(:updated_enrollment) do
          FactoryBot.create(
            :hbx_enrollment,
            household: family.active_household,
            coverage_kind: 'health',
            effective_on: initial_application.start_on,
            aasm_state: 'coverage_selected',
            sponsored_benefit_package_id: benefit_package.id,
            benefit_sponsorship_id: initial_application.benefit_sponsorship.id
          )
        end

        before { health_enrollment.update_attributes!(aasm_state: 'coverage_canceled') }

        it "returns the updated enrollment" do
          expect(profile.enrollments_for_billing).to include(updated_enrollment)
        end

        it "does not return the canceled original enrollment" do
          expect(profile.enrollments_for_billing).not_to include(health_enrollment)
        end
      end
    end

    describe "#billing_benefit_application" do
      let(:organization) do
        FactoryBot.build(:benefit_sponsors_organizations_general_organization,
                         :with_site,
                         :with_aca_shop_cca_employer_profile_initial_application)
      end

      let(:profile) { organization.employer_profile }
      let(:benefit_sponsorship) { organization.active_benefit_sponsorship }
      let(:application) { benefit_sponsorship.current_benefit_application }

      context "when billing date is given" do
        it "should return application and given billing date if given date covers benefit_application effective period" do
          date = application.start_on
          expect(profile.billing_benefit_application(date)).to eq [application, date]
        end

        it "should return nil and given billing date if given date not covers benefit_application effective period" do
          date = application.start_on - 1.month
          expect(profile.billing_benefit_application(date)).to eq [nil, date]
        end

        it "should return nil and given billing date if given date covers canceled benefit_application effective period " do
          application.assign_attributes(aasm_state: :canceled)
          date = application.start_on
          expect(profile.billing_benefit_application(date)).to eq [nil, date]
        end
      end

      context "when billing date is blank" do
        context "For initial employer" do
          it "should return initial published application effective date & initial start on date" do
            application
            expect(profile.billing_benefit_application).to eq [application, TimeKeeper.date_of_record.next_month]
          end
        end

        context "For renewal employer" do
          include_context "setup benefit market with market catalogs and product packages"
          include_context "setup renewal application"

          let(:renewal_state)           { :enrollment_open }
          let(:renewal_effective_date)  { TimeKeeper.date_of_record.beginning_of_month }
          let(:current_effective_date)  { renewal_effective_date.prev_year }
          let(:profile) { abc_profile }

          it "should return renewal published application effective date & renewal start on date" do
            expect(profile.billing_benefit_application).to eq [renewal_application, TimeKeeper.date_of_record.next_month]
          end

          it "should return renewal canceled application effective date & renewal start on date" do
            renewal_application.update_attributes!(aasm_state: :canceled)
            expect(profile.billing_benefit_application).to eq [nil, nil]
          end
        end
      end
    end
  end
end
