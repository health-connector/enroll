# frozen_string_literal: true

module Exchanges
  class AgentsController < ApplicationController
    include L10nHelper

    before_action :check_for_paper_app, only: [:resume_enrollment]

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    def home
      authorize :agent

      update_last_portal_visited
      @title = current_user.agent_title
      person_id = session[:person_id]
      @person = nil
      @person = Person.find(person_id) if person_id.present?
      if @person && !@person.csr_role && !@person.assister_role
        root = "http://#{request.env['HTTP_HOST']}/exchanges/agents/resume_enrollment?person_id=#{person_id}"
        hbx_profile = HbxProfile.find_by_state_abbreviation(aca_state_abbreviation)
        message_params = {
          sender_id: hbx_profile.id,
          parent_message_id: hbx_profile.id,
          from: 'Plan Shopping Web Portal',
          to: "Agent Mailbox",
          subject: "Account link for  #{@person.full_name}. ",
          body: "<a href='#{root}'>Link to access #{@person.full_name}</a>  <br>"
        }
        create_secure_message message_params, current_user.person, :inbox
      end
      session[:person_id] = nil
      session[:original_application_type] = nil
      render 'home'
    end

    def begin_employee_enrollment
      authorize :agent

      update_last_portal_visited
      session[:person_id] = nil
      session[:original_application_type] = params['original_application_type']
      redirect_to search_insured_employee_index_path
    end

    def begin_consumer_enrollment
      authorize :agent

      update_last_portal_visited
      session[:person_id] = nil
      session[:original_application_type] = params['original_application_type']
      redirect_to search_insured_consumer_role_index_path
    end

    def resume_enrollment
      if @person.resident_role&.bookmark_url
        redirect_to bookmark_url_path(@person.resident_role.bookmark_url)
      elsif @person.consumer_role&.bookmark_url
        redirect_to bookmark_url_path(@person.consumer_role.bookmark_url)
      elsif @person.employee_roles.last&.bookmark_url
        redirect_to bookmark_url_path(@person.employee_roles.last.bookmark_url)
      else
        redirect_to family_account_path
      end
    end

    def inbox
      authorize :agent

      update_last_portal_visited
      @inbox_provider = current_user.person
      @profile = @inbox_provider
      @folder = params[:folder] || 'inbox'
      @sent_box = false
    end

    def show
      authorize :agent

      update_last_portal_visited
    end

    private

    def bookmark_url_path(bookmark_url)
      uri = URI.parse(bookmark_url)
      bookmark_path = uri.path
      bookmark_path += "?#{uri.query}" unless uri.query.blank?
      bookmark_path
    end

    def update_last_portal_visited
      current_user.last_portal_visited = home_exchanges_agents_path
      current_user.save!
    end

    def check_for_paper_app
      session[:person_id] = params[:person_id]
      session[:original_application_type] = params['original_application_type']
      @person = Person.find(params[:person_id])
      return unless session[:original_application_type] == "paper"

      @person.set_ridp_for_paper_application(session[:original_application_type])
      redirect_to family_account_path
    end

    def user_not_authorized(_exception)
      flash[:error] = l10n('exchange.agent.not_authorized')
      redirect_to(request.referrer || root_path)
    end
  end
end
