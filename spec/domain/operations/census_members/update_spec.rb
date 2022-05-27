# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application"

RSpec.describe Operations::CensusMembers::Update, :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup renewal application"

  let(:family) { create(:family, :with_primary_family_member_and_dependent) }
  let(:person) { family.primary_person }
  let(:dependents) { family.family_members.where(is_primary_applicant: false) }
  let(:dependent) { dependents.first }
  let(:dependent_person) { dependent.person }
  let!(:census_dependent){ build(:census_dependent, first_name: dependent_person.first_name, last_name: dependent_person.last_name, dob: dependent_person.dob, ssn: dependent_person.ssn)}
  let(:census_dependents) { [census_dependent] }

  let!(:census_employee) do
    create(
      :benefit_sponsors_census_employee,
      :benefit_sponsorship => benefit_sponsorship,
      :employer_profile => abc_profile,
      :census_dependents => census_dependents
    )
  end
  let(:aasm_state) { 'coverage_enrolled' }

  let(:kind) { 'employer_sponsored' }

  let(:hbx_enrollment) do
    create(
      :hbx_enrollment,
      :with_enrollment_members,
      :with_product,
      household: family.active_household,
      aasm_state: aasm_state,
      kind: kind,
      effective_on: predecessor_application.start_on,
      rating_area_id: predecessor_application.recorded_rating_area_id,
      sponsored_benefit_id: predecessor_application.benefit_packages.first.health_sponsored_benefit.id,
      sponsored_benefit_package_id: predecessor_application.benefit_packages.first.id,
      benefit_sponsorship_id: predecessor_application.benefit_sponsorship.id,
      hbx_enrollment_members: [hbx_enrollment_member1, hbx_enrollment_member2],
      employee_role_id: employee_role.id
    )
  end

  let(:hbx_enrollment_member1) do
    build(
      :hbx_enrollment_member,
      applicant_id: family.find_family_member_by_person(person).id,
      is_subscriber: true,
      eligibility_date: Date.today
    )
  end

  let(:hbx_enrollment_member2) do
    build(
      :hbx_enrollment_member,
      applicant_id: dependent.id,
      is_subscriber: false,
      eligibility_date: Date.today
    )
  end

  let(:employee_role) { create(:benefit_sponsors_employee_role, person: person, census_employee_id: census_employee.id, benefit_sponsors_employer_profile_id: abc_profile.id)}

  describe "when updating person" do

    context 'when employee is on single roster' do

      before do
        hbx_enrollment
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        person.assign_attributes(first_name: "Johnny", middle_name: 'S', last_name: 'Smith')
        Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
        census_employee.reload
      end

      it 'should update census employee record' do
        expect(census_employee.first_name).to eq "Johnny"
        expect(census_employee.middle_name).to eq "S"
        expect(census_employee.last_name).to eq "Smith"
      end

      context 'when employee is in cobra status' do
        let(:kind) { 'employer_sponsored_cobra' }

        before do
          hbx_enrollment
          allow(person).to receive(:active_employee_roles).and_return([employee_role])
          person.assign_attributes(first_name: "Johnny", middle_name: 'S', last_name: 'Smith')
          Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
          census_employee.reload
        end

        it 'should update census employee record' do
          expect(census_employee.first_name).not_to eq "Johnny"
          expect(census_employee.last_name).not_to eq "Smith"
        end

      end
    end

    context 'when employee is on multiple rosters' do
      let(:current_effective_date_1)  { (TimeKeeper.date_of_record + 2.months).beginning_of_month.prev_year }

      let!(:service_area) do
        county_zip_id = create(:benefit_markets_locations_county_zip, county_name: 'Middlesex', zip: '01754', state: 'MA').id
        create(:benefit_markets_locations_service_area, county_zip_ids: [county_zip_id], active_year: current_effective_date_1.year)
      end

      let(:effective_period_1)          { current_effective_date_1..(current_effective_date_1.next_year.prev_day) }
      let(:open_enrollment_start_on_1)  { current_effective_date_1.prev_month }
      let(:open_enrollment_period_1)    { open_enrollment_start_on_1..(open_enrollment_start_on_1 + 5.days) }
      let!(:organization) do
        create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site)
      end
      let(:profile)               { organization.employer_profile }

      let!(:benefit_sponsorship_1) do
        benefit_sponsorship = profile.add_benefit_sponsorship
        benefit_sponsorship.aasm_state = :active
        benefit_sponsorship.save
        benefit_sponsorship
      end

      let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }
      let!(:service_areas_1) { benefit_sponsorship_1.service_areas_on(effective_period_1.min) }

      let(:benefit_sponsor_catalog_1) do
        benefit_sponsorship_1.benefit_sponsor_catalog_for(effective_period_1.min)
      end

      let!(:application) do
        create(
          :benefit_sponsors_benefit_application,
          :with_benefit_sponsor_catalog,
          :with_benefit_package,
          passed_benefit_sponsor_catalog: benefit_sponsor_catalog_1,
          benefit_sponsorship: benefit_sponsorship_1,
          effective_period: effective_period_1,
          aasm_state: :active,
          open_enrollment_period: open_enrollment_period_1,
          recorded_rating_area: rating_area,
          recorded_service_areas: service_areas_1,
          package_kind: :single_issuer,
          dental_package_kind: :single_product,
          dental_sponsored_benefit: false,
          fte_count: 5,
          pte_count: 0,
          msp_count: 0
        )
      end

      let!(:census_dependent_1){ build(:census_dependent, first_name: dependent_person.first_name, last_name: dependent_person.last_name, dob: dependent_person.dob)}
      let!(:census_employee_1) do
        create(
          :benefit_sponsors_census_employee,
          :benefit_sponsorship => benefit_sponsorship_1,
          :employer_profile => profile,
          :census_dependents => [census_dependent_1]
        )
      end
      let(:aasm_state) { 'coverage_enrolled' }

      let(:hbx_enrollment_1) do
        create(
          :hbx_enrollment,
          :with_enrollment_members,
          :with_product,
          household: family.active_household,
          aasm_state: aasm_state,
          effective_on: application.start_on,
          rating_area_id: application.recorded_rating_area_id,
          sponsored_benefit_id: application.benefit_packages.first.health_sponsored_benefit.id,
          sponsored_benefit_package_id: application.benefit_packages.first.id,
          benefit_sponsorship_id: benefit_sponsorship_1.id,
          hbx_enrollment_members: [hbx_enrollment_member_1, hbx_enrollment_member_2],
          employee_role_id: employee_role_1.id
        )
      end

      let(:hbx_enrollment_member_1) do
        build(
          :hbx_enrollment_member,
          applicant_id: family.find_family_member_by_person(person).id,
          is_subscriber: true,
          eligibility_date: Date.today
        )
      end

      let(:hbx_enrollment_member_2) do
        build(
          :hbx_enrollment_member,
          applicant_id: dependent.id,
          is_subscriber: false,
          eligibility_date: Date.today
        )
      end

      let(:employee_role_1) { create(:benefit_sponsors_employee_role, person: person, census_employee_id: census_employee_1.id, benefit_sponsors_employer_profile_id: profile.id)}

      context 'and enrolled under both employers' do
        before do
          hbx_enrollment
          hbx_enrollment_1
          allow(person).to receive(:active_employee_roles).and_return([employee_role, employee_role_1])
          person.assign_attributes(first_name: "Johnny", middle_name: 'S', last_name: 'Smith')
          Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
          census_employee.reload
          census_employee_1.reload
        end

        it 'should update census employee records on both rosters' do
          expect(census_employee.first_name).to eq "Johnny"
          expect(census_employee.middle_name).to eq "S"
          expect(census_employee.last_name).to eq "Smith"
          expect(census_employee_1.first_name).to eq "Johnny"
          expect(census_employee_1.middle_name).to eq "S"
          expect(census_employee_1.last_name).to eq "Smith"
        end
      end

      context 'and enrolled under only one employer' do
        before do
          hbx_enrollment
          allow(person).to receive(:active_employee_roles).and_return([employee_role, employee_role_1])
          person.assign_attributes(first_name: "Johnny", middle_name: 'S', last_name: 'Smith')
          Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
          census_employee.reload
          census_employee_1.reload
        end

        it 'should update census employee record' do
          expect(census_employee.first_name).to eq "Johnny"
          expect(census_employee.middle_name).to eq "S"
          expect(census_employee.last_name).to eq "Smith"
          expect(census_employee_1.first_name).not_to eq "Johnny"
          expect(census_employee_1.middle_name).not_to eq "S"
          expect(census_employee_1.last_name).not_to eq "Smith"
        end
      end
    end
  end

  describe "updating census dependent" do
    context "when enrolled" do
      before do
        hbx_enrollment
        dependent_person.assign_attributes(first_name: "Snow11", last_name: 'John11')
        Operations::CensusMembers::Update.new.call(person: dependent_person, family_member: dependent, action: 'update_census_dependent')
        census_employee.census_dependents.first.reload
      end

      it 'should update census dependent record' do
        expect(census_employee.census_dependents.first.first_name).to eq "Snow11"
        expect(census_employee.census_dependents.first.last_name).to eq "John11"
      end
    end

    context "when unenrolled" do
      before do
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        dependent_person.assign_attributes(first_name: "Test11", last_name: 'Snow11')
        Operations::CensusMembers::Update.new.call(person: dependent_person, family_member: dependent, action: 'update_census_dependent')
        census_employee.census_dependents.first.reload
      end

      it 'should not update existing census dependent record' do
        expect(census_employee.census_dependents.first.first_name).not_to eq "Test11"
        expect(census_employee.census_dependents.first.last_name).not_to eq "Snow11"
      end
    end

    context "when on expired/waived enrollment" do
      let(:aasm_state) { 'inactive' }

      before do
        hbx_enrollment
        dependent_person.assign_attributes(first_name: "Test11", last_name: 'Doe11')
        Operations::CensusMembers::Update.new.call(person: dependent_person, family_member: dependent, action: 'update_census_dependent')
      end

      it 'should not update census dependent record' do
        census_employee.census_dependents.first.reload
        expect(census_employee.census_dependents.first.first_name).not_to eq "Test11"
        expect(census_employee.census_dependents.first.last_name).not_to eq "Doe11"
      end
    end

    context "when on cobra enrollment" do
      let(:kind) { 'employer_sponsored_cobra' }

      before do
        hbx_enrollment
        dependent_person.assign_attributes(first_name: "Test11", last_name: 'Doe11')
        Operations::CensusMembers::Update.new.call(person: dependent_person, family_member: dependent, action: 'update_census_dependent')
      end

      it 'should not update census dependent record' do
        census_employee.census_dependents.first.reload
        expect(census_employee.census_dependents.first.first_name).not_to eq "Test11"
        expect(census_employee.census_dependents.first.last_name).not_to eq "Doe11"
      end
    end
  end

  describe 'updating census dependent relationship' do
    before do
      hbx_enrollment
      allow(person).to receive(:active_employee_roles).and_return([employee_role])
    end

    context "should update census dependent relationship if it is valid employee relationship kind" do
      it 'should update relationship' do
        expect(census_employee.census_dependents.first.employee_relationship).to eq 'spouse'
        dependent.update_relationship('domestic_partner') #calls operation
        expect(census_employee.census_dependents.first.reload.employee_relationship).to eq 'domestic_partner'
      end
    end

    context "should NOT update census dependent relationship if it is invalid employee relationship kind" do
      let(:relationship) { 'sibling' }

      it 'should not update relationship' do
        expect(census_employee.census_dependents.first.employee_relationship).to eq 'spouse'
        dependent.update_relationship('sibling') #calls operation
        expect(census_employee.census_dependents.first.reload.employee_relationship).to eq 'spouse'
      end
    end
  end

  describe 'when employee roster updates feature is turned off' do
    before do
      EnrollRegistry[:employee_roster_updates].feature.stub(:is_enabled).and_return(false)
      allow(person).to receive(:active_employee_roles).and_return([employee_role])
      person.assign_attributes(first_name: "Johnny12", middle_name: 'S12', last_name: 'Smith12')
      Operations::CensusMembers::Update.new.call(person: person, action: 'update_census_employee')
      census_employee.reload
    end

    it 'should not update census employee record' do
      expect(census_employee.first_name).not_to eq "Johnny12"
      expect(census_employee.middle_name).not_to eq "S12"
      expect(census_employee.last_name).not_to eq "Smith12"
    end
  end

  describe 'enrollment triggers' do
    context 'census employee demographics updated before enrollment purchase' do
      let(:aasm_state) { 'shopping' }

      before do
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        person.update_attributes(first_name: "Johnny22", middle_name: 'S22', last_name: 'Smith22')
        hbx_enrollment.select_coverage!
        census_employee.reload
      end


      it 'should trigger demographics updates on enrollment purchase' do
        expect(census_employee.first_name).to eq "Johnny22"
        expect(census_employee.middle_name).to eq "S22"
        expect(census_employee.last_name).to eq "Smith22"
      end
    end

    context 'census dependent demographics updated before enrollment purchase' do
      let(:aasm_state) { 'shopping' }

      before do
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        dependent_person.update_attributes(first_name: "Snow11", last_name: 'John11')
        hbx_enrollment.select_coverage!
      end

      it 'should trigger demographics updates on enrollment purchase' do
        dependent = census_employee.census_dependents.first.reload
        expect(dependent.first_name).to eq "Snow11"
        expect(dependent.last_name).to eq "John11"
      end
    end

    context 'when unenrolled census dependent is present on roster' do
      let(:aasm_state) { 'shopping' }
      let!(:unenrolled_cd) do
        build(
          :census_dependent,
          employee_relationship: 'child_under_26',
          dob: '01/12/2019',
          first_name: 'unenrolled',
          last_name: 'dependent'
        )
      end
      let(:census_dependents) { [census_dependent, unenrolled_cd] }

      before do
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        hbx_enrollment.select_coverage!
        census_employee.reload
      end

      it 'should delete census_dependent' do
        expect(census_employee.census_dependents.size).to eq 1
        expect(census_employee.reload.census_dependents.where(first_name: unenrolled_cd.first_name, last_name: unenrolled_cd.last_name).first).to be_nil
      end

      context 'when only primary enrolled' do

        let(:primary_hbx_enrollment_member) { hbx_enrollment_member1 }
        let(:hbx_enrollment) do
          create(
            :hbx_enrollment,
            :with_enrollment_members,
            :with_product,
            household: family.active_household,
            aasm_state: aasm_state,
            effective_on: predecessor_application.start_on,
            rating_area_id: predecessor_application.recorded_rating_area_id,
            sponsored_benefit_id: predecessor_application.benefit_packages.first.health_sponsored_benefit.id,
            sponsored_benefit_package_id: predecessor_application.benefit_packages.first.id,
            benefit_sponsorship_id: predecessor_application.benefit_sponsorship.id,
            hbx_enrollment_members: [primary_hbx_enrollment_member],
            employee_role_id: employee_role.id
          )
        end

        it 'should delete all census dependents' do
          expect(census_employee.census_dependents.size).to eq 0
        end
      end
    end
  end
end
