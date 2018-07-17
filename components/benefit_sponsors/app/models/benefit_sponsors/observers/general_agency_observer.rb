module BenefitSponsors
  module Observers
    class GeneralAgencyObserver
      include ::Acapi::Notifiers

      attr_accessor :notifier

      def notifications_send(model_instance, new_model_event)
        if new_model_event.present? &&  new_model_event.is_a?(BenefitSponsors::ModelEvents::ModelEvent)
          general_agency = new_model_event.klass_instance
       		if BenefitSponsors::ModelEvents::GeneralAgencyProfile::OTHER_EVENTS.include?(new_model_event.event_key)
		        event_object = new_model_event.options[:event_object]
		        if event_object.present?
		          deliver(recipient: general_agency, event_object: event_object, notice_event: new_model_event.event_key.to_s)
		        end
	      	end
        end
      end

      private

      def initialize
        @notifier = BenefitSponsors::Services::NoticeService.new
      end

      def deliver(recipient:, event_object:, notice_event:, notice_params: {})
        notifier.deliver(recipient: recipient, event_object: event_object, notice_event: notice_event, notice_params: notice_params)
      end
    end
  end
end
