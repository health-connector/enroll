# frozen_string_literal: true

require "forwardable"

module Eligible
  # The EligiblePeriodHandler class helps determine eligible periods
  # for a given eligibility record by analyzing its state history.
  #
  # @example
  #   eligible_record = Eligible::Eligibility.find(some_id)
  #   handler = Eligible::EligiblePeriodHandler.new(eligible_record)
  #   handler.is_eligible_on?(Date.today)
  class EligiblePeriodHandler
    extend Forwardable
    def_delegators :@eligible_record, :state_histories, :active_state, :inactive_state, :current_state, :eligible?

    # Initializes the handler with an eligible record
    #
    # @param [Eligible::Eligibility] eligible_record The eligibility record to process
    def initialize(eligible_record)
      @eligible_record = eligible_record
    end

    # Checks if the eligibility is active on the given date
    #
    # If the date is today's date, it checks the current eligibility status.
    # For past or future dates, it checks the eligibility periods.
    #
    # @param [Date] date The date for which to check eligibility
    #
    # @return [Boolean] True if eligible on the given date, false otherwise
    def is_eligible_on?(date)
      return eligible? if date == TimeKeeper.date_of_record

      eligible_periods.any? do |period|
        if period[:end_on].present?
          (period[:start_on]..period[:end_on]).cover?(date)
        else
          (period[:start_on]..period[:start_on].end_of_year).cover?(date)
        end
      end
    end

    # Returns a list of time periods during which the eligibility was active
    #
    # Coverage period of the eligibility will start from the first day of the calendar year
    # in which the eligibility was approved
    # coverage period end on the last day of the calendar year in which the eligibility was denied
    #
    # @return [Array<Hash>] Array of periods with :start_on and optional :end_on keys
    def eligible_periods
      eligible_periods = []
      date_range = {}
      state_histories.non_initial.each do |state_history|

        date_range[:start_on] ||= state_history.effective_on if state_history.to_state == active_state

        next unless date_range.present? && state_history.to_state == inactive_state

        date_range[:end_on] = state_history.effective_on.prev_day
        eligible_periods << date_range
        date_range = {}
      end

      eligible_periods << date_range unless date_range.empty?
      eligible_periods
    end
  end
end
