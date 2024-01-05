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
        response = subject.call(params).value!
        info = response.detect {|detail| detail[:employee_name] == census_employee.full_name}

        enrollments = family.reload.active_household.hbx_enrollments
        expect(benefit_application.aasm_state).to eq :active
        expect(enrollments.size).to eq 2
        expect(info).to match({
                                :employee_name => census_employee.full_name,
                                :status => 'reinstated',
                                :coverage_reinstated_on => TimeKeeper.date_of_record.beginning_of_month,
                                :enrollment_hbx_ids => enrollment.hbx_id
                              })
      end
    end
  end
end
