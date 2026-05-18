module BenefitSponsors
  module ModelEvents
    module Profile
      include DefineVariableHelper

      REGISTERED_EVENTS = []

      #TODO: The trigger for this notice is in the controller and it has to be eventually moved to observer pattern.
      #TODO: This is the temporary fix until then.
      OTHER_EVENTS = [
        :generate_initial_employer_invoice
      ]

      def trigger_model_event(event_name, event_options = {})
        return unless OTHER_EVENTS.include?(event_name)

        BenefitSponsors::Organizations::AcaShopCcaEmployerProfile.add_observer(BenefitSponsors::Observers::EmployerProfileObserver.new, [:update, :notifications_send])
        notify_observers(ModelEvent.new(event_name, self, event_options))
      end

      def notify_on_save
        return unless saved_change_to_aasm_state?

        REGISTERED_EVENTS.each do |event|
          next unless check_local_variable("is_#{event}", binding)

          event_options = {}
          notify_observers(ModelEvent.new(event, self, event_options))
        end
      end

      def is_transition_matching?(from: nil, to: nil, event: nil)
        aasm_matcher = lambda {|expected, current|
          expected.blank? || expected == current || (expected.is_a?(Array) && expected.include?(current))
        }

        current_event_name = aasm.current_event.to_s.gsub('!', '').to_sym
        aasm_matcher.call(from, aasm.from_state) && aasm_matcher.call(to, aasm.to_state) && aasm_matcher.call(event, current_event_name)
      end
    end
  end
end