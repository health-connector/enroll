module BenefitSponsors
  module ModelEvents
    module Document
      include DefineVariableHelper

      REGISTERED_EVENTS = [
        :initial_employer_invoice_available,
        :employer_invoice_available
      ]

      def notify_on_create
        if subject == 'initial_invoice' && identifier.present?
          is_initial_employer_invoice_available = true
        end

        if subject == 'invoice' && identifier.present?
          is_employer_invoice_available = true
        end

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