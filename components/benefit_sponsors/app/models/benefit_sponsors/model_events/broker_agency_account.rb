module BenefitSponsors
  module ModelEvents
    module BrokerAgencyAccount
      include DefineVariableHelper

      REGISTERED_EVENTS = [
        :broker_hired,
        :broker_fired
      ].freeze

      def notify_on_save
        if saved_change_to_is_active? && !is_active.nil?
          if is_active
            is_broker_hired = true
          end

          if !is_active
            is_broker_fired = true
          end
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