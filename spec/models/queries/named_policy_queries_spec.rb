# frozen_string_literal: true

require "rails_helper"

describe Queries::NamedPolicyQueries, "Policy Queries", dbclean: :after_each do
  # TODO: Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on) updated to new model in
  # app/models/queries/named_enrollment_queries.rb
  context "Shop Monthly Queries" do

    let(:effective_on) { TimeKeeper.date_of_record.end_of_month.next_day }

    let(:initial_employer) do
      FactoryBot.create(:employer_with_planyear, start_on: effective_on, plan_year_state: 'enrolled')
    end

    let(:initial_employees) do
      FactoryBot.create_list(:census_employee_with_active_assignment, 5, :old_case, hired_on: (TimeKeeper.date_of_record - 2.years), employer_profile: initial_employer,
                                                                                    benefit_group: initial_employer.published_plan_year.benefit_groups.first,
                                                                                    created_at: TimeKeeper.date_of_record.prev_year)
    end

    let(:renewing_employer) do
      FactoryBot.create(:employer_with_renewing_planyear, start_on: effective_on, renewal_plan_year_state: 'renewing_enrolled')
    end

    let(:renewing_employees) do
      FactoryBot.create_list(:census_employee_with_active_and_renewal_assignment, 5, :old_case, hired_on: (TimeKeeper.date_of_record - 2.years), employer_profile: renewing_employer,
                                                                                                benefit_group: renewing_employer.active_plan_year.benefit_groups.first,
                                                                                                renewal_benefit_group: renewing_employer.renewing_plan_year.benefit_groups.first,
                                                                                                created_at: TimeKeeper.date_of_record.prev_year)
    end

    let!(:initial_employee_enrollments) do
      initial_employees.inject([]) do |enrollments, ce|
        employee_role = create_person(ce, initial_employer)
        enrollments << create_enrollment(family: employee_role.person.primary_family, benefit_group_assignment: ce.active_benefit_group_assignment, employee_role: employee_role, submitted_at: effective_on.prev_month)
      end
    end

    let!(:cobra_employees) do
      FactoryBot.create_list(:census_employee_with_active_and_renewal_assignment, 5, :old_case, hired_on: (TimeKeeper.date_of_record - 2.years), employer_profile: renewing_employer,
                                                                                                benefit_group: renewing_employer.active_plan_year.benefit_groups.first,
                                                                                                renewal_benefit_group: renewing_employer.renewing_plan_year.benefit_groups.first,
                                                                                                created_at: TimeKeeper.date_of_record.prev_year)
    end

    let(:updating_cobra_employees) do
      cobra_employees.each do |employee|
        employee.aasm_state = 'cobra_linked'
        employee.cobra_begin_date = TimeKeeper.date_of_record.end_of_month
        employee.save
      end
    end

    let!(:cobra_employee_enrollments) do
      cobra_employees.inject([]) do |enrollments, ce|
        employee_role = create_person(ce, renewing_employer)
        enrollments << create_enrollment(family: employee_role.person.primary_family, kind: "employer_sponsored",benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: employee_role, status: 'terminated')
        enrollments << create_enrollment(family: employee_role.person.primary_family, kind: "employer_sponsored_cobra",benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: employee_role, status: 'auto_renewing',
                                         submitted_at: effective_on - 20.days)
      end
    end

    let!(:initial_employee_quiet_enrollments) do
      initial_employees.inject([]) do |enrollments, ce|
        employee_role = create_person(ce, initial_employer)
        submitted_at = ce.active_benefit_group_assignment.plan_year.start_on + Settings.aca.shop_market.initial_application.quiet_period.month_offset.months + Settings.aca.shop_market.initial_application.quiet_period.mday - 1.days
        enrollments << create_enrollment(family: employee_role.person.primary_family, benefit_group_assignment: ce.active_benefit_group_assignment, employee_role: employee_role, submitted_at: submitted_at)
      end
    end

    let!(:renewing_employee_enrollments) do
      renewing_employees.inject([]) do |enrollments, ce|
        employee_role = create_person(ce, renewing_employer)
        enrollments << create_enrollment(family: employee_role.person.primary_family, benefit_group_assignment: ce.active_benefit_group_assignment, employee_role: employee_role, submitted_at: effective_on - 20.days)
        enrollments << create_enrollment(family: employee_role.person.primary_family, benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: employee_role, status: 'auto_renewing', submitted_at: effective_on - 20.days)
      end
    end

    let(:renewing_employee_passives) do
      renewing_employee_enrollments.select(&:auto_renewing?)
    end

    let(:cobra_enrollments) do
      cobra_employee_enrollments.select(&:is_cobra_status?)
    end

    let(:feins) do
      [initial_employer.fein, renewing_employer.fein]
    end

    def create_person(census_employee, employer_profile)
      person = FactoryBot.create(:person, last_name: census_employeelast_name, first_name: census_employeefirst_name)
      employee_role = FactoryBot.create(:employee_role, person: person, census_employee: census_employee, employer_profile: employer_profile)
      census_employeeupdate_attributes({employee_role: employee_role})
      Family.find_or_build_from_employee_role(employee_role)
      employee_role
    end

    def create_enrollment(options = {})
      family = options[:family]
      benefit_group_assignment = options[:benefit_group_assignment]
      benefit_group = benefit_group_assignment.benefit_group
      employee_role = options[:employee_role]

      FactoryBot.create(:hbx_enrollment,:with_enrollment_members,
                        enrollment_members: [family.primary_applicant],
                        household: family.active_household,
                        coverage_kind: "health",
                        effective_on: options[:effective_date] || benefit_group.start_on,
                        enrollment_kind: options.fetch(:enrollment_kind, 'open_enrollment'),
                        kind: options.fetch(:kind, "employer_sponsored"),
                        submitted_at: options[:submitted_at],
                        benefit_group_id: benefit_group.id,
                        employee_role_id: employee_role.id,
                        benefit_group_assignment_id: benefit_group_assignment.id,
                        plan_id: benefit_group.reference_plan.id,
                        aasm_state: options.fetch(:status, 'coverage_selected'),
                        predecessor_enrollment_id: options[:predecessor_enrollment_id])
    end
    skip "shop monthly queries updated here in new model app/models/queries/named_enrollment_queries.rb need to move." do
      # context ".shop_monthly_enrollments", dbclean: :after_each do
      #
      #   context 'When passed employer FEINs and plan year effective date', dbclean: :after_each do
      #
      #     it 'should return coverages under given employers that includes initial, renewal & cobra enrollments' do
      #       enrollment_hbx_ids = (initial_employee_enrollments + renewing_employee_passives + cobra_enrollments).map(&:hbx_id)
      #       result = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      #
      #       expect(result.sort).to eq enrollment_hbx_ids.sort
      #     end
      #
      #     it 'should not return coverages under given employers if they are in quiet period' do
      #       quiet_enrollment_hbx_ids = (initial_employee_quiet_enrollments).map(&:hbx_id)
      #       result = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      #       expect(result & quiet_enrollment_hbx_ids).to eq []
      #     end
      #
      #     context 'When renewal enrollments purchased with QLE and not in quiet period' do
      #
      #       let(:qle_coverages) {
      #         renewing_employees[0..4].inject([]) do |enrollments, ce|
      #           family = ce.employee_role.person.primary_family
      #           enrollments << create_enrollment(family: family, benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: ce.employee_role, submitted_at: effective_on - 1.month + 8.days, enrollment_kind: 'special_enrollment')
      #         end
      #       }
      #
      #       before do
      #         renewing_employees[0..4].each do |ce|
      #           ce.employee_role.person.primary_family.active_household.hbx_enrollments.each { |enr| enr.cancel_coverage! }
      #         end
      #
      #         qle_coverages
      #       end
      #
      #       it 'should return QLE enrollments' do
      #         result = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      #         expect((result & qle_coverages.map(&:hbx_id)).sort).to eq qle_coverages.map(&:hbx_id).sort
      #       end
      #     end
      #
      #     context 'When renewal enrollments purchased with QLE and submitted before the drop date' do
      #       let(:qle_coverages_in_quiet_period) {
      #         renewing_employees[0..4].inject([]) do |enrollments, ce|
      #           family = ce.employee_role.person.primary_family
      #           enrollments << create_enrollment(family: family, benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: ce.employee_role,
      #                                            submitted_at: (ce.renewal_benefit_group_assignment.plan_year.start_on.prev_month + Settings.aca.shop_market.renewal_application.quiet_period.mday + 2.days), enrollment_kind: 'special_enrollment')
      #         end
      #       }
      #
      #       before do
      #         renewing_employees[0..4].each do |ce|
      #           ce.employee_role.person.primary_family.active_household.hbx_enrollments.each { |enr| enr.cancel_coverage! }
      #         end
      #
      #         qle_coverages_in_quiet_period
      #       end
      #
      #       it 'should return QLE enrollments' do
      #         result = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      #         expect((result & qle_coverages_in_quiet_period.map(&:hbx_id)).sort).to eq []
      #       end
      #     end
      #
      #     context 'When both active and passive renewal present' do
      #
      #       let(:actively_renewed_coverages) {
      #         renewing_employees[0..4].inject([]) do |enrollments, ce|
      #           enrollments << create_enrollment(family: ce.employee_role.person.primary_family, benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: ce.employee_role, submitted_at: effective_on - 1.month + 8.days)
      #         end
      #       }
      #
      #       before do
      #         renewing_employees[0..4].each do |ce|
      #           ce.employee_role.person.primary_family.active_household.hbx_enrollments.where(:"benefit_group_id".in => [ce.renewal_benefit_group_assignment.benefit_group_id]).each { |enr| enr.cancel_coverage! }
      #         end
      #       end
      #
      #       it 'should return active renewal' do
      #         active_renewal_hbx_ids = actively_renewed_coverages.map(&:hbx_id).sort
      #         result = Queries::NamedPolicyQueries.shop_monthly_enrollments(feins, effective_on)
      #         expect(result.sort & active_renewal_hbx_ids).to eq active_renewal_hbx_ids
      #       end
      #     end
      #   end
      # end

      # context '.shop_monthly_terminations' do
      #   context 'When passed employer FEINs and plan year effective date' do
      #
      #     context 'When EE created waivers' do
      #
      #       let!(:active_waivers) {
      #         enrollments = renewing_employees[0..4].inject([]) do |enrollments, ce|
      #           family = ce.employee_role.person.primary_family
      #           parent_enrollment = family.active_household.hbx_enrollments.detect{|enrollment| enrollment.effective_on == effective_on}
      #           enrollment = create_enrollment(family: family, benefit_group_assignment: ce.renewal_benefit_group_assignment, employee_role: ce.employee_role,
      #                                          submitted_at: effective_on - 10.days, status: 'inactive', predecessor_enrollment_id: parent_enrollment.id)
      #           enrollment.propogate_waiver
      #           enrollments << enrollment
      #         end
      #         enrollments
      #       }
      #
      #       it 'should return their previous enrollments as terminations' do
      #         termed_enrollments = active_waivers.collect{|en| en.family.active_household.hbx_enrollments.where(:effective_on => effective_on.prev_year).first}
      #         result = Queries::NamedPolicyQueries.shop_monthly_terminations(feins, effective_on)
      #         expect(result.sort).to eq termed_enrollments.map(&:hbx_id).sort
      #       end
      #     end
      #   end
      # end
    end
  end
end
