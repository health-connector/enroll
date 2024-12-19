module BenefitSponsors
  module ScheduledEvents
    class AcaShopScheduledEvents

      include ::Acapi::Notifiers
      include Config::AcaModelConcern

      attr_reader :new_date

      def self.advance_day(new_date)
        notify_logger("advance_day: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        self.new(new_date)
        notify_logger("advance_day: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def initialize(new_date)
        notify_logger("initialize: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        @new_date = new_date
        initialize_logger
        shop_daily_events
        auto_submit_renewal_applications
        # process_applications_missing_binder_payment #refs 39124 - Had to comment out as we got rid of states on BS.
        auto_transmit_monthly_ineligible_benefit_sponsors
        auto_cancel_ineligible_applications
        auto_transmit_monthly_benefit_sponsors
        close_enrollment_quiet_period
        notify_logger("initialize: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def shop_daily_events
        notify_logger("shop_daily_events: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        process_events_for { open_enrollment_begin }
        process_events_for { open_enrollment_end }
        process_events_for { benefit_begin }
        process_events_for { benefit_end }
        process_events_for { benefit_termination_pending }
        process_events_for { benefit_renewal }
        notify_logger("shop_daily_events: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def open_enrollment_begin
        notify_logger("open_enrollment_begin: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_begin_open_enrollment?(new_date)
        execute_sponsor_event(benefit_sponsorships, :begin_open_enrollment)
        notify_logger("open_enrollment_begin: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def open_enrollment_end
        notify_logger("open_enrollment_end: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_end_open_enrollment?(new_date)
        execute_sponsor_event(benefit_sponsorships, :end_open_enrollment)
        notify_logger("open_enrollment_end: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def benefit_begin
        notify_logger("benefit_begin: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_begin_benefit_coverage?(new_date)
        execute_sponsor_event(benefit_sponsorships, :begin_sponsor_benefit)
        notify_logger("benefit_begin: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def benefit_end
        notify_logger("benefit_end: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_end_benefit_coverage?(new_date)
        execute_sponsor_event(benefit_sponsorships, :end_sponsor_benefit)
        notify_logger("benefit_end: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def benefit_termination_pending
        notify_logger("benefit_termination_pending: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_terminate_pending_benefit_coverage?(new_date)
        execute_sponsor_event(benefit_sponsorships, :terminate_pending_sponsor_benefit)
        notify_logger("benefit_termination_pending: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def benefit_renewal
        notify_logger("benefit_renewal: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        months_prior_to_effective = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months.abs
        renewal_offset_days = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.day_of_month.days
        renewal_application_begin = (new_date + months_prior_to_effective.months - renewal_offset_days)

        if renewal_application_begin.mday == 1
          benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.may_renew_application?(renewal_application_begin.prev_day)
          execute_sponsor_event(benefit_sponsorships, :renew_sponsor_benefit)
        end
        notify_logger("benefit_renewal: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def process_applications_missing_binder_payment
        notify_logger("process_applications_missing_binder_payment: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        application_effective_date = new_date.next_month.beginning_of_month
        scheduler = BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new
        binder_next_day = scheduler.calculate_open_enrollment_date(application_effective_date)[:binder_payment_due_date].next_day

        if new_date == binder_next_day
          benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_transition_as_initial_ineligible?(application_effective_date)
          execute_sponsor_event(benefit_sponsorships, :mark_initial_ineligible)
        end
        notify_logger("process_applications_missing_binder_payment: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def auto_cancel_ineligible_applications
        notify_logger("auto_cancel_ineligible_applications: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        if new_date.mday == 1
          benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_cancel_ineligible_application?(new_date)
          execute_sponsor_event(benefit_sponsorships, :auto_cancel_ineligible)
        end
        notify_logger("auto_cancel_ineligible_applications: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def auto_submit_renewal_applications
        notify_logger("auto_submit_renewal_applications: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        if new_date.day == Settings.aca.shop_market.renewal_application.force_publish_day_of_month
          effective_on = new_date.next_month.beginning_of_month
          benefit_sponsorships = BenefitSponsorships::BenefitSponsorship.may_auto_submit_application?(effective_on)
          execute_sponsor_event(benefit_sponsorships, :auto_submit_application)
        end
        notify_logger("auto_submit_renewal_applications: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def auto_transmit_monthly_benefit_sponsors
        notify_logger("auto_transmit_monthly_benefit_sponsors: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        if aca_shop_market_transmit_scheduled_employers
           # [26, 27, 28, 29, 30, 31] >= 26
          if (new_date.prev_day.mday + 1) >= aca_shop_market_employer_transmission_day_of_month
            transmit_scheduled_benefit_sponsors(new_date)
          end
        end
        notify_logger("auto_transmit_monthly_benefit_sponsors: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def auto_transmit_monthly_ineligible_benefit_sponsors
        notify_logger("auto_transmit_monthly_ineligible_benefit_sponsors: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        if EnrollRegistry.feature_enabled?(:automation_of_ineligible_benefit_sponsors)
          if (new_date.mday) == EnrollRegistry[:automation_of_ineligible_benefit_sponsors].setting(:ineligible_employer_transmission_day_of_month).item
            auto_transmit_ineligible_renewal_benefit_sponsors(new_date)
          end
        end
        notify_logger("auto_transmit_monthly_ineligible_benefit_sponsors: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def transmit_scheduled_benefit_sponsors(new_date, feins=[])
        notify_logger("transmit_scheduled_benefit_sponsors: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        start_on = new_date.prev_day.next_month.beginning_of_month
        transition_at = (new_date.prev_day.mday + 1) == aca_shop_market_employer_transmission_day_of_month ? nil : new_date.prev_day
        benefit_sponsors = BenefitSponsors::BenefitSponsorships::BenefitSponsorship
        benefit_sponsors = benefit_sponsors.find_by_feins(feins) if feins.any?

        renewal_benefit_sponsorships = benefit_sponsors.may_transmit_renewal_enrollment?(start_on, transition_at)
        execute_sponsor_event(renewal_benefit_sponsorships, :transmit_renewal_eligible_event)
        execute_sponsor_event(renewal_benefit_sponsorships, :transmit_renewal_carrier_drop_event)

        initial_benefit_sponsorships = benefit_sponsors.may_transmit_initial_enrollment?(start_on, transition_at)
        execute_sponsor_event(initial_benefit_sponsorships, :transmit_initial_eligible_event)
        notify_logger("transmit_scheduled_benefit_sponsors: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def auto_transmit_ineligible_renewal_benefit_sponsors(new_date, feins=[])
        notify_logger("auto_transmit_ineligible_renewal_benefit_sponsors: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        start_on = new_date.prev_day.next_month.beginning_of_month
        benefit_sponsors = BenefitSponsors::BenefitSponsorships::BenefitSponsorship
        benefit_sponsors = benefit_sponsors.find_by_feins(feins) if feins.any?

        ineligible_renewal_benefit_sponsorships = benefit_sponsors.may_transmit_as_renewal_ineligible?(start_on)
        execute_sponsor_event(ineligible_renewal_benefit_sponsorships, :transmit_ineligible_renewal_carrier_drop_event)
        notify_logger("auto_transmit_ineligible_renewal_benefit_sponsors: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def close_enrollment_quiet_period
        notify_logger("close_enrollment_quiet_period: Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        if new_date.prev_day.mday == Settings.aca.shop_market.initial_application.quiet_period.mday
          effective_on = (new_date.prev_day.beginning_of_month - Settings.aca.shop_market.initial_application.quiet_period.month_offset.months).to_s(:db)
          notify("acapi.info.events.employer.initial_employer_quiet_period_ended", {:effective_on => effective_on})
        end
        notify_logger("close_enrollment_quiet_period: Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      private

      def execute_sponsor_event(benefit_sponsorships, event)
        notify_logger("Event: #{event}. Process started at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
        BenefitSponsors::BenefitSponsorships::BenefitSponsorshipDirector.new(new_date).process(benefit_sponsorships, event)
        notify_logger("Event: #{event}. Process ended at #{Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%m-%d-%Y %H:%M:%S')}")
      end

      def process_events_for(&block)
        begin
          block.call
        rescue Exception => e
          @logger.error e.message
          @logger.error e.backtrace.join("\n")
        end
      end

      def notify_logger(message)
        @logger.info(message)
        log(message) unless Rails.env.test?
      end

      def initialize_logger
        @logger = Logger.new("#{Rails.root}/log/aca_shop_scheduled_events.log") unless defined? @logger
      end
    end
  end
end
