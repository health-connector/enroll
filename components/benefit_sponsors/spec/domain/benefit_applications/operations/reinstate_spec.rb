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

    before do
      allow_any_instance_of(::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService).to receive(:renew_application).and_return([true, nil, nil])
    end

    context 'reinstate benefit application' do
      it 'should reinstate benefit application' do
        expect(benefit_application.aasm_state).to eq :terminated
        subject.call(params)
        item = benefit_application.reload.latest_benefit_application_item

        expect(benefit_application.aasm_state).to eq :active
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

        expect(benefit_application.aasm_state).to eq :active
        expect(bga.reload.end_on).to eq nil
      end
    end

    context 'reinstate benefit application with edi' do
      it 'should send application event' do
        expect_any_instance_of(::BenefitSponsors::Observers::BenefitApplicationObserver).to receive(:notify).with(
          "acapi.info.events.employer.benefit_coverage_period_reinstated",
          {:employer_id => benefit_application.sponsor_profile.hbx_id, :is_trading_partner_publishable => true, :event_name => "benefit_coverage_period_reinstated"}
        )
        subject.call(params)
      end
    end

    context 'reinstate benefit application with census employees and enrollments' do
      let(:person)          { create(:person) }
      let(:family)          { create(:family, :with_primary_family_member, person: person)}
      let!(:census_employee) do
        census_employee = create(
          :census_employee,
          benefit_sponsorship: benefit_sponsorship,
          employer_profile: benefit_sponsorship.profile,
          benefit_group: current_benefit_package
        )
        census_employee.employee_role = create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, person: person)
        census_employee.save
        census_employee
      end
      let(:employee_role) { census_employee.employee_role }
      let(:sponsored_benefit) { current_benefit_package.sponsored_benefit_for(:health) }

      let!(:enrollment) do
        FactoryGirl.create(
          :hbx_enrollment,
          household: family.latest_household,
          coverage_kind: :health,
          effective_on: current_effective_date,
          kind: "employer_sponsored",
          benefit_sponsorship_id: benefit_sponsorship.id,
          sponsored_benefit_package_id: current_benefit_package.id,
          sponsored_benefit_id: sponsored_benefit.id,
          employee_role_id: employee_role.id,
          aasm_state: 'coverage_selected'
        )
      end

      let!(:benefit_application) do
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

      it 'should reinstate enrollment' do
        enrollments = family.active_household.hbx_enrollments
        expect(enrollments.size).to eq 1
        subject.call(params).value!

        enrollments = family.reload.active_household.hbx_enrollments
        expect(benefit_application.aasm_state).to eq :active
        expect(enrollments.size).to eq 2
      end

      it 'should send enrollment event' do
        expect_any_instance_of(HbxEnrollment).to receive(:notify)
        subject.call(params)
      end

      context 'when eligible for renewal' do
        let(:renewal_day) do
          months_prior_to_effective = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months.abs
          (benefit_application.earliest_benefit_application_item.effective_period.max + 1.day).to_date - months_prior_to_effective.months
        end

        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(renewal_day + 1)
        end

        it 'should call service to renew application' do
          expect_any_instance_of(::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService).to receive(:renew_application).and_return([true, nil, nil])
          subject.call(params).value!
        end
      end
    end

    context "without overlapping application" do
      let(:new_start_on) { benefit_application.effective_period.max.to_date.next_day }
      let!(:draft_application) do
        FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, :with_benefit_package,
                           passed_benefit_sponsor_catalog: benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship,
                           open_enrollment_period: benefit_application.open_enrollment_period, recorded_rating_area: rating_area,
                           recorded_service_areas: service_areas, package_kind: package_kind, dental_package_kind: dental_package_kind,
                           dental_sponsored_benefit: dental_sponsored_benefit, fte_count: 5, pte_count: 0, msp_count: 0,
                           aasm_state: :draft,
                           benefit_application_items: [build(:benefit_sponsors_benefit_application_item, effective_period: new_start_on..(new_start_on.next_year - 1.day), state: :draft)])
      end

      it 'should reinstate benefit application if there is no overlapping application' do
        expect(benefit_application.aasm_state).to eq :terminated
        subject.call(params)
        item = benefit_application.reload.latest_benefit_application_item

        expect(benefit_application.aasm_state).to eq :active
        expect(item.effective_period.min).to eq reinstate_on
        expect(item.state).to eq :reinstate
        expect(item.action_kind).to eq 'reinstate'
      end
    end

    context "with overlapping application" do
      let!(:draft_application) do
        FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, :with_benefit_package,
                           passed_benefit_sponsor_catalog: benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship,
                           open_enrollment_period: benefit_application.open_enrollment_period, recorded_rating_area: rating_area,
                           recorded_service_areas: service_areas, package_kind: package_kind, dental_package_kind: dental_package_kind,
                           dental_sponsored_benefit: dental_sponsored_benefit, fte_count: 5, pte_count: 0, msp_count: 0,
                           aasm_state: overlapping_state,
                           benefit_application_items: [build(:benefit_sponsors_benefit_application_item, effective_period: benefit_application.effective_period, state: overlapping_state)])
      end

      context "with draft overlapping application" do
        let(:overlapping_state) { :draft }
        it 'returns failure ' do
          result = subject.call(params)
          expect(result.failure?).to eq true
          expect(result.failure).to eq ["Reinstate failed due to overlapping benefit applications"]
        end
      end

      context "with terminated overlapping application" do
        let(:overlapping_state) { :terminated }
        it 'returns failure ' do
          result = subject.call(params)
          expect(result.failure?).to eq true
          expect(result.failure).to eq ["Reinstate failed due to overlapping benefit applications"]
        end
      end
    end

    context "without overlapping application" do
      let(:new_start_on) { benefit_application.effective_period.max.to_date.next_day }
      let!(:draft_application) do
        FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, :with_benefit_package,
                           passed_benefit_sponsor_catalog: benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship,
                           open_enrollment_period: benefit_application.open_enrollment_period, recorded_rating_area: rating_area,
                           recorded_service_areas: service_areas, package_kind: package_kind, dental_package_kind: dental_package_kind,
                           dental_sponsored_benefit: dental_sponsored_benefit, fte_count: 5, pte_count: 0, msp_count: 0,
                           aasm_state: :draft,
                           benefit_application_items: [build(:benefit_sponsors_benefit_application_item, effective_period: new_start_on..(new_start_on.next_year - 1.day), state: :draft)])
      end

      it 'should reinstate benefit application if there is no overlapping application' do
        expect(benefit_application.aasm_state).to eq :terminated
        subject.call(params)
        item = benefit_application.reload.latest_benefit_application_item

        expect(benefit_application.aasm_state).to eq :active
        expect(item.effective_period.min).to eq reinstate_on
        expect(item.state).to eq :reinstate
        expect(item.action_kind).to eq 'reinstate'
      end
    end

    context "with overlapping application" do
      let!(:draft_application) do
        FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, :with_benefit_package,
                           passed_benefit_sponsor_catalog: benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship,
                           open_enrollment_period: benefit_application.open_enrollment_period, recorded_rating_area: rating_area,
                           recorded_service_areas: service_areas, package_kind: package_kind, dental_package_kind: dental_package_kind,
                           dental_sponsored_benefit: dental_sponsored_benefit, fte_count: 5, pte_count: 0, msp_count: 0,
                           aasm_state: overlapping_state,
                           benefit_application_items: [build(:benefit_sponsors_benefit_application_item, effective_period: benefit_application.effective_period, state: overlapping_state)])
      end

      context "with draft overlapping application" do
        let(:overlapping_state) { :draft }
        it 'returns failure ' do
          result = subject.call(params)
          expect(result.failure?).to eq true
          expect(result.failure).to eq ["Reinstate failed due to overlapping benefit applications"]
        end
      end

      context "with terminated overlapping application" do
        let(:overlapping_state) { :terminated }
        it 'returns failure ' do
          result = subject.call(params)
          expect(result.failure?).to eq true
          expect(result.failure).to eq ["Reinstate failed due to overlapping benefit applications"]
        end
      end
    end
  end
end
