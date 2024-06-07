# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.shared_context "setup shop families enrollments", :shared_context => :metadata do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees with benefits"

  let!(:census_employee) { benefit_sponsorship.census_employees.first }
  let!(:ee_person) { FactoryBot.create(:person, :with_employee_role, :with_family, first_name: census_employee.first_name, last_name: census_employee.last_name, dob: census_employee.dob, ssn: census_employee.ssn, gender: census_employee.gender) }
  let!(:employee_role) do
    ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
    ee_person.employee_roles.first
  end
  let!(:family)       { ee_person.primary_family }
  let!(:hbx_enrollment) do
    hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members,
                                       household: family.active_household,
                                       aasm_state: "shopping",
                                       effective_on: initial_application.start_on,
                                       rating_area_id: initial_application.recorded_rating_area_id,
                                       sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                       sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                       benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                       employee_role_id: employee_role.id)
    hbx_enrollment.benefit_sponsorship = benefit_sponsorship
    hbx_enrollment.save!
    hbx_enrollment
  end
  let(:qle_kind) {FactoryBot.create(:qualifying_life_event_kind, :effective_on_event_date)}

  let(:sep) do
    sep = family.special_enrollment_periods.new
    sep.effective_on_kind = 'date_of_event'
    sep.qualifying_life_event_kind = qle_kind
    sep.qle_on = TimeKeeper.date_of_record - 7.days
    sep.start_on = sep.qle_on
    sep.end_on = sep.qle_on + 30.days
    sep.save
    sep
  end

  before :each do
    census_employee.employee_role_id = employee_role.id
    census_employee.save
    employee_role.census_employee_id = census_employee.id
    ee_person.save
  end
end