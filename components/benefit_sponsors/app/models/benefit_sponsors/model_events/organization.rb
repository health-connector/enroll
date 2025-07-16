module BenefitSponsors
  module ModelEvents
    module Organization
      include DefineVariableHelper

      REGISTERED_EVENTS = [
        :welcome_notice_to_employer
      ]

      def notify_on_create

        if self.employer_profile
          is_welcome_notice_to_employer = true
        end

        REGISTERED_EVENTS.each do |event|
          next unless check_local_variable("is_#{event}", binding)

          event_options = {}
          notify_observers(ModelEvent.new(event, self, event_options))
        end
      end
    end
  end
end