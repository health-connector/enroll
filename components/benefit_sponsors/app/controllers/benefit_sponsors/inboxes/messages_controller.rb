module BenefitSponsors
  module Inboxes
    class MessagesController < ApplicationController
      before_action :set_current_user
      before_action :find_message
      before_action :set_sent_box, only: [:show, :destroy], if: :is_broker?

      def show
        if is_broker?
          authorize @inbox_provider, :show_inbox_message?, policy_class: BenefitSponsors::PersonPolicy
        elsif @inbox_provider.instance_of?(Person)
          authorize @inbox_provider, :can_read_inbox?, policy_class: BenefitSponsors::PersonPolicy
        else
          authorize @inbox_provider, :can_read_inbox?
        end
        BenefitSponsors::Services::MessageService.for_show(@message, @current_user)
        respond_to do |format|
          format.html
          format.js
        end
      end

      def destroy
        if is_broker?
          authorize @inbox_provider, :destroy_inbox_message?, policy_class: BenefitSponsors::PersonPolicy
        elsif @inbox_provider.instance_of?(Person)
          authorize @inbox_provider, :can_read_inbox?, policy_class: BenefitSponsors::PersonPolicy
        else
          authorize @inbox_provider, :can_read_inbox?
        end
        BenefitSponsors::Services::MessageService.for_destroy(@message)
        flash[:notice] = "Successfully deleted inbox message."
        if params[:url].present?
          @inbox_url = params[:url]
        end
      end

      private

      def set_current_user
        @current_user = current_user
      end

      def set_sent_box
        @sent_box = true
      end

      def is_broker?
        return (@inbox_provider.class.to_s == "Person") && (/.*BrokerAgencyProfile$/.match(@inbox_provider.broker_role.broker_agency_profile._type))
      end

      def find_inbox_provider
        person = Person.where(id: params["id"])

        if person.present? && person.first.broker_role.present?
          @inbox_provider = person.first
        elsif find_profile.present?
          @inbox_provider = find_profile
          @inbox_provider_name = @inbox_provider.legal_name if /.*EmployerProfile$/.match(@inbox_provider._type)
        end
      end

      def find_profile
        @profile = BenefitSponsors::Organizations::Profile.find(params["id"])
      end

      def find_message
        @message = @inbox_provider.inbox.messages.by_message_id(params["message_id"]).to_a.first
      end
    end
  end
end
