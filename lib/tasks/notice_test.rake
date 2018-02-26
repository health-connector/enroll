namespace :notice_test do
  desc "Load the carrier data"
  task :notice_rake1 => :environment do
    COMPOSITE_TIER_TRANSLATIONS ||= {
      'Employee': 'employee_only',
      'Employee + Spouse': 'employee_and_spouse',
      'Employee + Dependent(s)': 'employee_and_one_or_more_dependents',
      'Family': 'family'
    }.with_indifferent_access
    Caches::PlanDetails.load_record_cache!
    cps = ENV['cp'].split(' ').uniq

    start_date = TimeKeeper.date_of_record.next_month.next_month.beginning_of_month
    cps.each do |carrier_profile|
      ["silver", "gold", "platinum"].each do |metal_level|
        ref_plan_id = Plan.where(carrier_profile_id: carrier_profile, renewal_plan_id: {:$exists=> true}, metal_level: metal_level).all.first.id
        emp = FactoryGirl.create(:notices_employer_profile, :adds)
        org = emp.organization
        FactoryGirl.create(:employer_attestation, :with_attestation_document, employer_profile: emp)
        py1 = FactoryGirl.create(:notice_custom_plan_year, employer_profile: emp, ref_plan_id: ref_plan_id, start_on: start_date - 1.year, aasm_state: 'published', is_conversion: false)
        py1 = emp.plan_years.first
        bg1 = py1.benefit_groups.first
        ce_owner = FactoryGirl.create(:census_employee, :owner, employer_profile: emp)
        ce = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 16.months, employer_profile: emp)
        ce1 = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 18.months, employer_profile: emp)
        ce2 = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 17.months, employer_profile: emp)
        ce3 = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 17.months, employer_profile: emp)
        ce4 = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 18.months, employer_profile: emp)
        ce6 = FactoryGirl.create(:census_employee, hired_on: TimeKeeper.date_of_record - 16.months, employer_profile: emp)
        puts "Organization name is #{org.legal_name}"
        emp.census_employees.all.each do |cemp|
          person_record = FactoryGirl.create(:person, ssn: cemp.ssn, dob: cemp.dob, gender: cemp.gender, first_name: cemp.first_name, last_name: cemp.last_name)
          u = FactoryGirl.create(:user, person: person_record,
                                       email: cemp.email.address,
                                       oim_id: cemp.email.address,
                                       password: "Abcd1234!",
                                       password_confirmation: "Abcd1234!")
          puts "Census Employee id is #{u.id}"
          Factories::EnrollmentFactory.build_employee_role(person_record, person_record, emp, cemp, cemp.hired_on)
        end
        emp.employee_roles.each do |er|
          hbex = FactoryGirl.create(:hbx_enrollment, :open_enrollment, :shop, :with_enrollment_members, enrollment_members: er.families.family_members, household: er.families.households.first,
           effective_on: py1.start_on, plan_id: bg1.reference_plan_id, benefit_group_id: bg1.id,
           benefit_group_assignment_id: er.census_employee.benefit_group_assignments.where(aasm_state: "initialized").first.id)
          er.census_employee.benefit_group_assignments.where(aasm_state: "initialized").first.update_attributes!(aasm_state: "coverage_selected", hbx_enrollment_id: hbex.id)
          hbex.record_transition
        end
        today = TimeKeeper.date_of_record
        py1.advance_date! if today > py1.open_enrollment_end_on
        py1.advance_date! if today >= py1.start_on
        py1.advance_date! if today > py1.start_on
        ce2.terminate_employment!(TimeKeeper.date_of_record - 7.days)
        ce6.terminate_employment!(TimeKeeper.date_of_record + 7.days)
        ce3.terminate_employment!(TimeKeeper.date_of_record - 10.days)
        ce4.terminate_employment!(TimeKeeper.date_of_record - 5.days)
        ce4.reload
        ce3.reload
        rehire_census_employee(ce3, TimeKeeper.date_of_record - 5.days)
        cobra_census_employee(ce4, TimeKeeper.date_of_record.next_month + 5.days)
        plan_id = Plan.find(bg1.reference_plan_id).renewal_plan_id
        py2 = FactoryGirl.create(:notice_custom_plan_year, employer_profile: emp, start_on: start_date, ref_plan_id: plan_id, aasm_state: "renewing_draft", renewing: true, with_dental: false)
        CensusEmployee.by_benefit_group_ids([BSON::ObjectId.from_string(bg1.id.to_s)]).active.all.each do |cemp|
          bg2 = py2.benefit_groups.first
          if cemp.active_benefit_group_assignment
            bga = BenefitGroupAssignment.new(benefit_group: bg2, start_on: bg2.start_on, is_active: false)
            bga.renew_coverage
            cemp.benefit_group_assignments << bga
            cemp.renewal_benefit_group_assignment.save
          end
        end
      end
    end
  end

  private
  def rehire_census_employee(ce, rehired_date)
    new_ce = ce.replicate_for_rehire
    new_ce.hired_on = rehired_date
    if new_ce.valid? && ce.valid?
       ce.save!
       new_ce.save!
       new_ce.build_address if new_ce.address.blank?
       new_ce.add_default_benefit_group_assignment
       new_ce.construct_employee_role_for_match_person
    end
  end

  def cobra_census_employee(ce, cobra_date)
    ce.update_for_cobra(cobra_date, nil)  if ce.can_elect_cobra?
  end
end
