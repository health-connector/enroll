module Enrollments::EnrollmentPeriods
  class EnrollmentPeriod

    FEHB_KINDS            = [:open, :special, :new_hire, :newly_designated]
    ACA_SHOP_KINDS        = [:open, :special, :new_hire, :cobra]
    ACA_INDIVIDUAL_KINDS  = [:open, :special, :native_american]

    attr_accessor :market_kind, :title, :begin_on, :end_on, :effective_on_dates

    def initialize(enrollment_period)
      @title                  = ""
      @market_kind            = market_kind  # => BenefitMarkets::BENEFIT_MARKET_KINDS
      @enrollment_date_range  = begin_on..end_on
      @effective_on_dates     = [effective_on_dates]
    end

    def may_enroll_on?(enrollment_date)
      @enrollment_date_range.includes?(enrollment_date)
    end

    def effective_date_for(enrollment_date)
    end

    def duration_in_days
      (@enrollment_date_range.max - @enrollment_date_range.min).to_i unless @enrollment_date_range.blank?
    end

    def days_remaining
      [(@enrollment_date_range.max - TimeKeeper.date_of_record), 0].max.to_i unless @enrollment_date_range.blank?
    end

    def eligibile_members
    end

  end
end
