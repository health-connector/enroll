module Enrollments::EnrollmentPeriods
  class EnrollmentPeriodBuilder

    def initialize(person, market_kind = :any)
      @person             = person
      @primary_family     = @person.primary_family
      @market_kind        = market_kind
      @enrollment_periods = []

      case @market_kind
      when :aca_individual_market
        load_aca_individual_market_enrollment_periods
      when :aca_shop_market
        load_aca_shop_market_enrollment_periods
      when :fehb_market
        load_fehb_market_enrollment_periods
      else
        raise ArgumentError.new("unknown market_kind: #{@market_kind}")
      end

      load_special_enrollment_periods
    end

    # Active or next open enrollment, native_american open enrollment
    def load_aca_individual_market_enrollment_periods

      build_native_american_enrollment_periods
    end

    # Active or next open enrollment, new_hire enrollment
    def load_aca_shop_market_enrollment_periods
      @person.employee_roles.reduce([]) do |list, employee_role|

        if !employee_role.employer_profile.default_benefit_group.is_congress?
          if employee_role.is_active?
            list << build_aca_shop_open_enrollment_period(employee_role)
          elsif employee_role.is_cobra_status?
            list << build_aca_shop_cobra_enrollment_period(employee_role)
          end
          list
        end
      end

      # Pick up new hires from CensusEmployee to catch unlinked EmployerProfiles
      build_new_hire_enrollment_periods
    end

    # Active or next open enrollment, new_hire enrollment, newly_designated enrollment
    def load_fehb_market_enrollment_periods
      @person.employee_roles.reduce([]) do |list, employee_role|

        if employee_role.employer_profile.default_benefit_group.is_congress?
          if employee_role.is_active?
            list << build_aca_shop_open_enrollment_period(employee_role)
          elsif employee_role.is_cobra_status?
            list << build_aca_shop_cobra_enrollment_period(employee_role)
          end
          list
        end
      end

      build_new_hire_enrollment_periods
      build_newly_designated_enrollment_periods
    end

    def build_new_hire_enrollment_periods
      matched_members = match_census_employees

      matched_members.select do |matched_member|
        # matched_member.
      end

      new_hire_benefit_sponsorships =
      new_hire_benefit_sponsorships.each do |benefit_sponsorship|
      end
    end

    def build_newly_designated_enrollment_periods
    end

    def build_aca_shop_open_enrollment_period(employee_role)
      if is_under_open_enrollment?
        # Get dates for current open enrollment
        # enrollment_date_range =
        # effective_on_dates =
      else
        # Get dates for current open enrollment
        # enrollment_date_range =
        # effective_on_dates =
      end

      OpenEnrollmentPeriod.new(
          title: "Open Enrollment Period",
          market_kind: @market_kind,
          employer_profile: employee_role.employer_profile,
          enrollment_date_range: enrollment_date_range,
          effective_on_dates: [effective_on],
          # benefit_package:
        )

    end

    def build_aca_shop_cobra_enrollment_period(employee_role)
      enrollment_months_length = Settings.aca.shop_market.cobra_enrollment_period
      effective_on = employee_role.terminated_on + 1.day
      enrollment_deadline = effective_on + enrollment_months_length - 1.day
      enrollment_date_range = effective_on..enrollment_deadline

      CobraEnrollmentPeriod.new(
          title: "COBRA Enrollment Period",
          market_kind: @market_kind,
          employer_profile: employee_role.employer_profile,
          enrollment_date_range: enrollment_date_range,
          effective_on_dates: [effective_on]
        )
    end

    def build_native_american_enrollment_periods
    end

    def load_special_enrollment_periods
      @primary_family.special_enrollment_periods.reduce([]) do |list, sep|
        SpecialEnrollmentPeriod.new(
            title: "Special Enrollment Period",
            market_kind: @market_kind,
            enrollment_period: sep.start_on..sep.end_on,
            effective_dates: [sep.effective_on] + [sep.optional_effective_on],
            family_sep: sep,
          )

        list << builder.enrollment_period
      end
    end

    def enrollment_periods
      @enrollment_periods
    end

    private

    def match_census_employees
      CensusEmployee.matchable(@person.ssn, @person.dob).to_a + CensusEmployee.unclaimed_matchable(@person.ssn, @person.dob).to_a
    end


  end
end
