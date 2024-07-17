# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::Operations::BenefitApplications::ConfirmationDetails, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees"

  context 'with invalid params' do

    context 'missing benefit application' do
      let(:params) do
        { benefit_sponsorship: benefit_sponsorship, sequence_id: 0 }
      end

      it 'returns failure' do
        expect(subject.call(**params).failure?).to eq true
      end
    end

    context 'missing benefit_application' do
      let(:params) do
        { benefit_application: initial_application, sequence_id: 0 }
      end

      it 'returns failure' do
        expect(subject.call(**params).failure?).to eq true
      end
    end

    context 'missing sequence_id' do
      let(:params) do
        { benefit_application: initial_application, benefit_sponsorship: benefit_sponsorship }
      end

      it 'returns failure' do
        expect(subject.call(**params).failure?).to eq true
      end
    end

    context 'invalid benefit application' do
      let(:params) do
        { benefit_sponsorship: benefit_sponsorship, sequence_id: 0, benefit_application: double }
      end

      it 'returns failure' do
        expect(subject.call(**params).failure?).to eq true
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
      { benefit_sponsorship: benefit_sponsorship, sequence_id: 1, benefit_application: benefit_application }
    end


    context 'reinstate retroactive cancelled benefit application with census employees and enrollments' do
      let(:person)          { create(:person) }
      let(:family)          { create(:family, :with_primary_family_member, person: person)}
      let!(:census_employee) do
        census_employee = create(
          :census_employee,
          benefit_sponsorship: benefit_sponsorship,
          employer_profile: benefit_sponsorship.profile,
          benefit_group: current_benefit_package
        )
        census_employee.employee_role_id = create(:employee_role, benefit_sponsors_employer_profile_id: abc_profile.id, person: person).id
        census_employee.save
        census_employee
      end
      let(:employee_role) { census_employee.employee_role }
      let(:sponsored_benefit) { current_benefit_package.sponsored_benefit_for(:health) }
      let(:reinstate_on) { benefit_application.start_on }

      let!(:enrollment) do
        FactoryBot.create(
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
          waiver_reason: waiver_reason,
          product_id: product_id
        )
      end

      let(:waiver_reason) { nil }
      let(:product_id) { BSON::ObjectId.new }

      let!(:benefit_application) do
        initial_application.benefit_application_items.create(
          sequence_id: 1,
          effective_period: initial_application.effective_period,
          state: :retroactive_canceled
        )
        initial_application.cancel!
        initial_application.reload
      end

      context 'with active enrollment' do

        before :all do
          DatabaseCleaner.clean
        end

        it 'should return enrollment details' do
          employee_details = subject.call(**params).value![:employee_details]
          expect(employee_details.map {|detail| detail[:enrollment_details] }.reject(&:empty?)).to eq [enrollment.hbx_id]
        end
      end
    end
  end
end
