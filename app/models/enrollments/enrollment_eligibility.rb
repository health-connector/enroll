module Enrollments
  class EnrollmentEligibility

    def initialize(person, benefit_market_kinds = [])
      @person                 = person
      @benefit_market_kinds   = benefit_market_kinds #|| SITE.benefit_market_kinds
      @all_enrollment_periods = load_enrollment_periods
    end

    def enrollment_periods_eligible_on(enrollment_date = TimeKeeper.date_of_record)
      @all_enrollment_periods.reduce([]) do |list, enrollment_period|
        list << enrollment_period if enrollment_period.may_enroll_on?(enrollment_date)
      end
    end


    def is_eligible_to_enroll_on?(date_of_hire, enrollment_date = TimeKeeper.date_of_record)

      # Length of time prior to effective date that EE may purchase plan
      Settings.aca.shop_market.earliest_enroll_prior_to_effective_on.days

      # Length of time following effective date that EE may purchase plan
      Settings.aca.shop_market.latest_enroll_after_effective_on.days

      # Length of time that EE may enroll following correction to Census Employee Identifying info
      Settings.aca.shop_market.latest_enroll_after_employee_roster_correction_on.days

    end

    def earliest_enrollment_period_for(benefit_market_kinds)
    end


    def all_enrollment_periods
      @all_enrollment_periods
    end

    def open_enrollment_periods
      @all_enrollment_periods.reduce([]) do |list, enrollment_period|
        list << enrollment_period if enrollment_period.class.demodulize == OpenEnrollmentPeriod
      end
    end

    def special_enrollment_periods
      @all_enrollment_periods.reduce([]) do |list, enrollment_period|
        list << enrollment_period if enrollment_period.class.demodulize == SpecialEnrollmentPeriod
      end
    end

    def new_hire_enrollment_periods
      @all_enrollment_periods.reduce([]) do |list, enrollment_period|
        list << enrollment_period if enrollment_period.class.demodulize == NewHireEnrollmentPeriod
      end
    end


    private

    def load_enrollment_periods
      @benefit_market_kinds.reduce([]) do |list, benefit_market_kind|
        builder = EnrollmentPeriodBuilder.new(@person, benefit_market_kind)
        list << builder.enrollment_periods
      end
    end

  end
end
