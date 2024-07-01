# frozen_string_literal: true

module IndividualMarket
  module Exchanges
    class AgentsController < ApplicationController
      before_action :check_agent_role

      def begin_consumer_enrollment
        session[:person_id] = nil
        session[:original_application_type] = params['original_application_type']
        redirect_to search_insured_consumer_role_index_path
      end

      def check_agent_role
        unless current_user.has_agent_role? || current_user.has_hbx_staff_role? || current_user.has_broker_role? || current_user.has_general_agency_staff_role?
          redirect_to root_path, :flash => { :error => "You must be an Agent:  CSR, CAC, IPA or a Broker" }
        end
        current_user.last_portal_visited = home_exchanges_agents_path
        current_user.save!
      end
    end
  end
end
