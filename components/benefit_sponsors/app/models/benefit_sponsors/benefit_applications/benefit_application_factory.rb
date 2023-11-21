module BenefitSponsors
  module BenefitApplications
    class BenefitApplicationFactory

      attr_accessor :benefit_sponsorship

      def self.call(benefit_sponsorship, args)
        new(benefit_sponsorship, args).benefit_application
      end

      def self.validate(_benefit_application)
        # TODO: Add validations
        # Validate open enrollment period
        true
      end

      def initialize(benefit_sponsorship, args)
        @benefit_sponsorship = benefit_sponsorship
        @benefit_application = benefit_sponsorship.benefit_applications.new
        assign_application_attributes(args.except(:effective_period))
        @benefit_application.benefit_application_items.build({
                                                               effective_period: args[:effective_period],
                                                               current_state: @benefit_application.aasm_state,
                                                               sequence_id: 0
                                                             })
        @benefit_application.pull_benefit_sponsorship_attributes
      end

      attr_reader :benefit_application

      protected

      def assign_application_attributes(args)
        return nil if args.blank?

        args.each_pair do |k, v|
          @benefit_application.send("#{k}=".to_sym, v)
        end
      end
    end

    class BenefitApplicationFactoryError < StandardError; end
  end
end
