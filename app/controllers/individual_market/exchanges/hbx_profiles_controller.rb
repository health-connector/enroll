# frozen_string_literal: true

module IndividualMarket
  module Exchanges
    class HbxProfilesController < ApplicationController
      include HtmlScrubberUtil
      include StringScrubberUtil
      include ::Exchanges::HbxProfilesHelper
      include ::DataTablesAdapter
      include ::DataTablesSearch
      include ::Pundit
      include ::SepAll
      include ::Config::AcaHelper

      layout 'single_column'

      def request_help
        role, agent = identify_role_and_agent(params)

        status_text = if role
                        process_role_message(role, agent, params)
                      else
                        call_customer_service(params[:firstname].strip, params[:lastname].strip)
                      end

        broker_view = render_to_string 'insured/families/_consumer_brokers_widget', layout: false
        render json: { broker: broker_view, status: status_text }
      end

      private

      def identify_role_and_agent(params)
        if params[:type]
          cac_flag = params[:type] == 'CAC'
          match = CsrRole.find_by_name(params[:firstname], params[:lastname], cac_flag)
          if match.count.positive?
            agent = match.first
            role = cac_flag ? 'Certified Applicant Counselor' : 'Customer Service Representative'
            return [role, agent]
          end
        elsif params[:broker].present?
          agent = Person.find(params[:broker])
          consumer = Person.find(params[:person])
          consumer.primary_family.hire_broker_agency(agent.broker_role.id)
          return ['Broker', agent]
        elsif params[:assister].present?
          agent = Person.find(params[:assister])
          return ['In-Person Assister', agent]
        end
        [nil, nil]
      end

      def process_role_message(role, agent, params)
        status_text = "Message sent to #{role} #{agent.full_name} <br>"
        if find_email(agent, role)
          agent_assistance_messages(params, agent, role)
        else
          status_text = "Agent has no email. Please select another."
        end
        status_text
      end

      def find_email(agent, role)
        if role == 'Broker'
          agent.try(:broker_role).try(:email).try(:address)
        else
          agent.try(:user).try(:email)
        end
      end

      def agent_assistance_messages(params, agent, role)
        # Extract sanitized user details
        details = extract_and_sanitize_user_details(params)

        # Construct the email body
        body = construct_message_body(details, params)

        # Retrieve the HbxProfile
        hbx_profile = HbxProfile.find_by_state_abbreviation(aca_state_abbreviation)

        # Build secure message parameters
        message_params = {
          sender_id: hbx_profile.id,
          parent_message_id: hbx_profile.id,
          from: 'Plan Shopping Web Portal',
          to: 'Agent Mailbox',
          subject: "Please contact #{details[:first_name]} #{details[:last_name]}.",
          body: body
        }

        # Send secure messages
        send_secure_messages(message_params, hbx_profile, agent)

        # Send email notification
        send_email_notification(
          agent: agent,
          role: role,
          first_name: details[:first_name],
          full_name: details[:full_name],
          email: details[:email],
          person_present: params[:person].present?
        )
      end

      def extract_and_sanitize_user_details(params)
        if params[:person].present?
          insured = Person.find(params[:person])
          {
            first_name: sanitize_html(insured.first_name),
            last_name: sanitize_html(insured.last_name),
            full_name: sanitize_html(insured.full_name),
            email: sanitize_html(insured.emails.last.try(:address) || insured.try(:user).try(:email))
          }
        else
          {
            first_name: sanitize_html(params[:first_name]),
            last_name: sanitize_html(params[:last_name]),
            full_name: sanitize_html("#{params[:first_name]} #{params[:last_name]}"),
            email: sanitize_html(params[:email])
          }
        end
      end

      def construct_message_body(details, params)
        if params[:person].present?
          root = sanitize_html("http://#{request.env['HTTP_HOST']}/exchanges/agents/resume_enrollment?person_id=#{params[:person]}&original_application_type:")
          <<~HTML
            Please contact #{details[:first_name]} #{details[:last_name]}. <br>
            Plan shopping help has been requested by #{details[:email]} <br>
            <a href="#{root}phone">Assist Customer</a> <br>
          HTML
        else
          <<~HTML
            Please contact #{details[:first_name]} #{details[:last_name]}. <br>
            Plan shopping help has been requested by #{details[:email]} <br>
          HTML
        end
      end

      def send_secure_messages(message_params, hbx_profile, agent)
        create_secure_message(message_params, hbx_profile, :sent)
        create_secure_message(message_params, agent, :inbox)
      end

      def send_email_notification(params)
        result = UserMailer.new_client_notification(
          find_email(params[:agent], params[:role]),
          params[:first_name],
          params[:full_name],
          params[:role],
          params[:email],
          params[:person_present]
        )
        result.deliver_now
      end

      def call_customer_service(first_name, last_name)
        "No match found for #{first_name} #{last_name}.  Please call Customer Service at: (855)532-5465 for assistance.<br/>"
      end
    end
  end
end
