module ModelEvents
  module EmployerProfile
    include ModelEvents::DefineVariableHelper

    REGISTERED_EVENTS = [
      :initial_employee_plan_selection_confirmation
    ]

    #TODO: The trigger for this notice is in the controller and it has to be eventually moved to observer pattern.
    #TODO: This is the temporary fix until then.
    OTHER_EVENTS = [
      :generate_initial_employer_invoice,
      :broker_hired_confirmation_to_employer,
      :welcome_notice_to_employer
    ]

    def trigger_model_event(event_name, event_options = {})
      return unless OTHER_EVENTS.include?(event_name)

        notify_observers(ModelEvent.new(event_name, self, event_options))

    end

    def notify_on_save
      return unless saved_change_to_aasm_state?

        if is_transition_matching?(to: :binder_paid, from: :eligible, event: :binder_credited)
          is_initial_employee_plan_selection_confirmation = true
        end

        REGISTERED_EVENTS.each do |event|
          next unless check_local_variable("is_#{event}", binding)

          # event_name = ("on_" + event.to_s).to_sym
          event_options = {} # instance_eval(event.to_s + "_options") || {}
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

    def renewal_employer_initial_application_submitted(employer_wrapper)
      is_broker_associated_for_notifications(employer_wrapper)
    end

    def renewal_employer_open_enrollment_completed(employer_wrapper)
      is_broker_associated_for_notifications(employer_wrapper)
    end
  end
end
