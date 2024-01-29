# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"
RSpec.describe BenefitSponsors::Operations::BenefitApplications::Revise, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees"

  context 'with invalid params' do

    context 'missing benefit application' do
      let(:params) do
        { transmit_to_carrier: true, reinstate_on: TimeKeeper.date_of_record.beginning_of_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing application key(s).'
      end
    end

    context 'missing transmit_to_carrier' do
      let(:params) do
        { benefit_application: initial_application, reinstate_on: TimeKeeper.date_of_record.beginning_of_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing application key(s).'
      end
    end

    context 'missing reinstate_on' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: initial_application }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing reinstate on date.'
      end
    end

    context 'missing termination_kind' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: double,
          reinstate_on: TimeKeeper.date_of_record.beginning_of_month, termination_reason: 'Other', term_date: TimeKeeper.date_of_record.next_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing terminate key(s).'
      end
    end

    context 'missing termination_reason' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: double,
          reinstate_on: TimeKeeper.date_of_record.beginning_of_month, termination_kind: 'voluntary', term_date: TimeKeeper.date_of_record.next_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing terminate key(s).'
      end
    end

    context 'missing term_date' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: double,
          reinstate_on: TimeKeeper.date_of_record.beginning_of_month, termination_kind: 'voluntary', termination_reason: 'Other' }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Missing terminate key(s).'
      end
    end

    context 'invalid benefit application' do
      let(:params) do
        { transmit_to_carrier: true, benefit_application: double, reinstate_on: TimeKeeper.date_of_record.beginning_of_month,
          termination_kind: 'voluntary', termination_reason: 'Other', term_date: TimeKeeper.date_of_record.next_month }
      end

      it 'returns failure' do
        expect(subject.call(params).failure).to eq 'Not a valid Benefit Application'
      end
    end
  end

  context 'with valid params' do
    let(:term_date) { TimeKeeper.date_of_record.prev_month.end_of_month }
    let(:initial_term_date) { TimeKeeper.date_of_record.prev_month.beginning_of_month - 1.day }
    let(:benefit_application) do
      effective_period = initial_application.effective_period
      updated_dates = effective_period.min..initial_term_date
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
      { transmit_to_carrier: true, benefit_application: benefit_application, reinstate_on: reinstate_on,
        termination_kind: 'voluntary', termination_reason: 'Other', term_date: term_date }
    end

    before do
      allow_any_instance_of(::BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService).to receive(:renew_application).and_return([true, nil, nil])
    end

    context 'revise benefit application' do
      it 'should reinstate and terminate benefit application' do
        sequence_id = benefit_application.latest_benefit_application_item.sequence_id
        subject.call(params)
        items = benefit_application.reload.benefit_application_items.select { |item| item.sequence_id > sequence_id }
        expect(items.size).to eq 2
        reinstate_item, term_item = items

        expect(reinstate_item.state).to eq :reinstate
        expect(reinstate_item.effective_period.min).to eq reinstate_on
        expect(term_item.state).to eq :terminated
        expect(term_item.effective_period.max).to eq term_date
      end
    end

    context 'revise benefit application with census employees' do
      it 'should reinstate and term benefit group assignments' do
        bga = census_employees.first.benefit_group_assignments[0]
        # expect(bga.end_on).to eq initial_term_date
        subject.call(params)

        expect(benefit_application.aasm_state).to eq :terminated
        expect(bga.reload.end_on).to eq term_date
      end
    end

    context 'revise benefit application with edi' do
      it 'should send application event for reinstate and term' do
        expect_any_instance_of(::BenefitSponsors::Observers::BenefitApplicationObserver).to receive(:notify).with(
          "acapi.info.events.employer.benefit_coverage_period_reinstated",
          {:employer_id => benefit_application.sponsor_profile.hbx_id, :is_trading_partner_publishable => true, :event_name => "benefit_coverage_period_reinstated"}
        )

        expect_any_instance_of(::BenefitSponsors::Observers::BenefitApplicationObserver).to receive(:notify).with(
          "acapi.info.events.employer.benefit_coverage_period_terminated_voluntary",
          {:employer_id => benefit_application.sponsor_profile.hbx_id, :is_trading_partner_publishable => true, :event_name => "benefit_coverage_period_terminated_voluntary"}
        )
        subject.call(params)
      end
    end

    context 'revise benefit application with census employees and enrollments' do
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
          aasm_state: 'coverage_selected',
          waiver_reason: nil,
          product_id: BSON::ObjectId.new
        )
      end

      let!(:benefit_application) do
        effective_period = initial_application.effective_period
        updated_dates = effective_period.min..initial_term_date
        initial_application.benefit_application_items.create(
          sequence_id: 1,
          effective_period: updated_dates,
          state: :terminated
        )
        initial_application.terminate_enrollment!
        initial_application.reload
      end

      it 'should reinstate and terminate enrollment' do
        enrollments = family.active_household.hbx_enrollments
        expect(enrollments.size).to eq 1
        subject.call(params).value!

        enrollments = family.reload.active_household.hbx_enrollments
        expect(benefit_application.aasm_state).to eq :terminated
        expect(enrollments.size).to eq 2
        expect(enrollments.last.aasm_state).to eq 'coverage_terminated'
      end
    end
  end
end
