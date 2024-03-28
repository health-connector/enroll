module BenefitSponsors
  module Exporters
    class BenefitApplicationIssuers
      include Config::AcaModelConcern

      attr_reader :lines

      def retrieve(compare_date = TimeKeeper.date_of_record)
        # if MA term/cancel gets promoted before this update :aasm_state to include :binder_paid on line 11
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:benefit_applications => { :$elemMatch => query(compare_date) }).each do |benefit_sponsorship|
          applications_query(benefit_sponsorship.benefit_applications, compare_date).each do |benefit_application|
            @lines += BenefitSponsors::Serializers::BenefitApplicationIssuer.to_csv(benefit_application)
          end
        end
      end

      # Using earliest benefit_application_item since we're only interested at either active / enrollment_eligible aasm states.
      def query(compare_date)
        # if compare_date is after the transmission day then we need to find both effective_period that
        # end after today and are active and we need to find those the about to begin and are enrollment_eligible
        # because gluedb will have already been notified about them and need issuer_ids backfilled
        if (compare_date.prev_day.mday + 1) >= aca_shop_market_employer_transmission_day_of_month
          { "$or" => [{:"benefit_application_items.0.effective_period.max".gt => compare_date, :aasm_state => :active},
                      {:"benefit_application_items.0.effective_period.min" => compare_date.next_month.beginning_of_month, :aasm_state => :enrollment_eligible}] }
        # if compare_date is before the transmission day then we ened to only need active because gluedb
        # has not yet been notified
        else
          { :"benefit_application_items.0.effective_period.max".gt => compare_date, :aasm_state => :active }
        end
      end

      def applications_query(applications, compare_date)
        # if compare_date is after the transmission day then we need to find both effective_period that
        # end after today and are active and we need to find those the about to begin and are enrollment_eligible
        # because gluedb will have already been notified about them and need issuer_ids backfilled

        if (compare_date.prev_day.mday + 1) >= aca_shop_market_employer_transmission_day_of_month
          applications.select do |application|
            (application.latest_benefit_application_item.effective_period.max > compare_date && application.aasm_state == :active) ||
              ((application.earliest_benefit_application_item.effective_period.min.to_date == compare_date.next_month.beginning_of_month.to_date) && application.aasm_state == :enrollment_eligible)
          end
        # if compare_date is before the transmission day then we ened to only need active because gluedb
        # has not yet been notified
        else
          applications.select { |application| application.earliest_benefit_application_item.effective_period.max > compare_date && application.aasm_state == :active }
        end
      end

      def write
        File.open('active_plans_and_issuers.csv', 'w') do |csv|
          csv.puts "employer_hbx_id,employer_fein,effective_period_start_on,effective_period_end_on,carrier_hbx_id,carrier_fein"
          @lines.each { |line| csv.puts line }
        end
      end

      def initialize(file_name = "active_plans_and_issuers.csv")
        @file_name = file_name
        @lines = []
        retrieve
      end
    end
  end
end
