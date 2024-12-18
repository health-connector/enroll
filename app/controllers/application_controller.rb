# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit
  include Config::SiteConcern
  include Config::AcaConcern
  include Config::ContactCenterConcern
  include Acapi::Notifiers
  include ::L10nHelper
  include ::FileUploadHelper

  after_action :update_url, :unless => :format_js?
  helper BenefitSponsors::Engine.helpers

  def format_js?
    request.format.js?
  end

  # force_ssl

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception, prepend: true

  ## Devise filters
  before_action :check_concurrent_sessions
  before_action :require_login, unless: :authentication_not_required?
  before_action :authenticate_user_from_token!
  before_action :authenticate_me!

  # for i18L
  before_action :set_locale

  # for current_user
  before_action :set_current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  rescue_from ActionController::InvalidCrossOriginRequest do |exception|
    error_message = {
      :error => {
        :message => exception.message,
        :inspected => exception.inspect,
        :backtrace => exception.backtrace.join("\n")
      },
      :url => request.original_url,
      :method => request.method,
      :parameters => params.to_s,
      :source => request.env["HTTP_REFERER"]
    }

    log(JSON.dump(error_message), {:severity => 'critical'})
  end

  rescue_from ActionController::InvalidAuthenticityToken, :with => :bad_token_due_to_session_expired

  def access_denied
    render file: 'public/403.html', status: 403
  end

  def bad_token_due_to_session_expired
    flash[:warning] = "Session expired."
    respond_to do |format|
      format.html { redirect_to root_path }
      format.js   { render text: "window.location.assign('#{root_path}');" }
      format.json { render json: { :token_expired => root_url }, status: :unauthorized }
    end
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore

    flash[:error] = "Access not allowed for #{policy_name}.#{exception.query}, (Pundit policy)"
    respond_to do |format|
      format.json { render nothing: true, status: :forbidden }
      format.html { redirect_to(request.referrer || root_path)}
      format.js { head :forbidden }
    end
  end

  def authenticate_me!
    # Skip auth if you are trying to log in
    return true if ["welcome","saml", "broker_roles", "office_locations", "invitations", 'security_question_responses'].include?(controller_name.downcase) || action_name == 'unsupportive_browser'

    authenticate_user!
  end

  def create_sso_account(user, personish, timeout, account_role = "individual")
    unless user.idp_verified?
      IdpAccountManager.create_account(user.email, user.oim_id, stashed_user_password, personish, account_role, timeout)
      session[:person_id] = personish.id
      session.delete("stashed_password")
      user.switch_to_idp!
    end
    #TODO: TREY KEVIN JIM CSR HAS NO SSO_ACCOUNT
    session[:person_id] = personish.id if current_user.try(:person).try(:agent?)
    yield
  end

  private

  def check_concurrent_sessions
    return unless EnrollRegistry.feature_enabled?(:prevent_concurrent_sessions) && concurrent_sessions? && current_user.has_hbx_staff_role?

    flash[:error] = l10n('devise.sessions.signed_out_concurrent_session')
    sign_out current_user
  end

  def concurrent_sessions?
    # If the session token differs from the token stored in the db
    # a new login for this user is detected.
    # Checking for User class prevents spec breaking for Doubles.
    # Currently only enabled for admin users.
    current_user.instance_of?(User) && (session[:login_token] != current_user&.current_login_token)
  end

  def strong_params
    params.permit!
  end

  def secure_message(from_provider, to_provider, subject, body)
    message_params = {
      sender_id: from_provider.id,
      parent_message_id: to_provider.id,
      from: from_provider.legal_name,
      to: to_provider.legal_name,
      subject: subject,
      body: body
    }

    create_secure_message(message_params, to_provider, :inbox)
    create_secure_message(message_params, from_provider, :sent)
  end

  def create_secure_message(message_params, inbox_provider, folder)
    message = Message.new(message_params)
    message.folder = Message::FOLDER_TYPES[folder]
    msg_box = inbox_provider.inbox
    msg_box.post_message(message)
    msg_box.save
  end

  def set_locale
    I18n.locale = extract_locale_or_default

    # TODO: (Clinton De Young) - I have set the locale to be set by the browser for convenience.  We will
    # need to add this into the appropriate place below after we have finished testing everything.
    #
    # requested_locale = params[:locale] || user_preferred_language || extract_locale_from_accept_language_header || I18n.default_locale
    # requested_locale = I18n.default_locale unless I18n.available_locales.include? requested_locale.try(:to_sym)
    # I18n.locale = requested_locale
  end

  def extract_locale_or_default
    requested_locale = ((request.env['HTTP_ACCEPT_LANGUAGE'] || 'en').scan(/^[a-z]{2}/).first.presence || 'en').try(:to_sym)
    I18n.available_locales.include?(requested_locale) ? requested_locale : I18n.default_locale
  end

  def extract_locale_from_accept_language_header
    return unless request.env['HTTP_ACCEPT_LANGUAGE']

    request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
  end

  def update_url
    return unless [
      ["employer_profiles", "show"],
      ["families", "home"],
      ["profiles", "new"],
      ["profiles", "show"],
      ["hbx_profiles", "show"]
    ].any? { |controller, action| controller_name == controller && action_name == action }

    return if current_user.last_portal_visited == request.original_url

    current_user.last_portal_visited = request.original_url
    current_user.save
  end

  def user_preferred_language
    current_user.try(:preferred_language)
  end

  protected

  # Broker Signup form should be accessibile for anonymous users
  def authentication_not_required?
    action_name == 'unsupportive_browser' ||
      devise_controller? ||
      (controller_name == "broker_roles") ||
      (controller_name == "office_locations") ||
      (controller_name == "invitations") ||
      (controller_name == "saml") ||
      (controller_name == 'security_question_responses')
  end

  def check_for_special_path
    if site_sign_in_routes.include? request.path
      redirect_to main_app.new_user_session_path
      nil
    elsif site_create_routes.include? request.path
      redirect_to main_app.new_user_registration_path
      nil
    end
  end

  def require_login
    unless current_user
      session[:portal] = url_for(strong_params) unless request.format.js?
      if site_uses_default_devise_path?
        check_for_special_path
        redirect_to main_app.new_user_session_path
      else
        redirect_to main_app.new_user_registration_path
      end
    end
  rescue StandardError => e
    message = {}
    message[:message] = "Application Exception - #{e.message}"
    message[:session_person_id] = session[:person_id] if session[:person_id]
    message[:user_id] = current_user.id if current_user
    message[:oim_id] = current_user.oim_id if current_user
    message[:url] = request.original_url
    message[:params] = params if params
    log(message, :severity => 'error')
  end

  def after_sign_in_path_for(resource)
    if request.referrer =~ /sign_in/
      # Redirect the user to the main page to ensure that they submit missing security question responses
      return root_path if resource&.is_active_without_security_question_responses?

      session[:portal] || resource.try(:last_portal_visited) || root_path
    else
      session[:portal] || request.referer || root_path
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    logout_saml_index_path
  end

  def authenticate_user_from_token!
    user_token = params[:user_token].presence
    user = user_token && User.find_by_authentication_token(user_token.to_s)
    return unless user

    sign_in user, store: false
    flash[:notice] = "Signed in Successfully."
  end

  def cur_page_no(alph = "a")
    page_string = params.permit(:page)[:page]
    page_string.blank? ? alph : page_string.to_s
  end

  def page_alphabets(source, field)
    # A good optimization would be an aggregate
    # source.collection.aggregate([{ "$group" => { "_id" => { "$substr" => [{ "$toUpper" => "$#{field}"},0,1]}}}, "$sort" =>{"_id"=>1} ]).map do
    #   |object| object["_id"]
    # end
    # but source.collection acts on the entire collection (Model.all) hence cant be used here as source is a Mongoid::Criteria
    source.distinct(field).collect {|word| word.first.upcase}.uniq.sort
  rescue StandardError
    ("A".."Z").to_a
  end

  def set_current_user
    User.current_user = current_user
    SAVEUSER[:current_user_id] = current_user.try(:id)
    session_id = SessionTaggedLogger.extract_session_id_from_request(request)
    return if SessionIdHistory.where(session_id: session_id).present?

    SessionIdHistory.create(session_id: session_id, session_user_id: current_user.try(:id), sign_in_outcome: "Successful", ip_address: request.remote_ip)
  end

  def clear_current_user
    User.current_user = nil
    SAVEUSER[:current_user_id] = nil
  end

  append_after_action :clear_current_user

  def set_current_person(required: true)
    @person = if current_user.try(:person).try(:agent?) && session[:person_id].present?
                Person.find(session[:person_id])
              else
                current_user.person
              end
    redirect_to logout_saml_index_path if required && !set_current_person_succeeded?
  end

  def set_current_person_succeeded?
    return true if @person

    message = {}
    message[:message] = 'Application Exception - person required'
    message[:session_person_id] = session[:person_id]
    message[:user_id] = current_user.id
    message[:oim_id] = current_user.oim_id
    message[:url] = request.original_url
    log(message, :severity => 'error')
    false
  end

  def actual_user
    if current_user.try(:person).try(:agent?)
      nil
    else
      current_user
    end
  end

  def market_kind_is_employee?
    /employee/.match(current_user.last_portal_visited) || (session[:last_market_visited] == 'shop' && !/consumer/.match(current_user.try(:last_portal_visited)))
  end

  def market_kind_is_consumer?
    /consumer/.match(current_user.last_portal_visited) || (session[:last_market_visited] == 'individual' && !/employee/.match(current_user.try(:last_portal_visited)))
  end

  def save_bookmark(role, bookmark_url)
    if role && bookmark_url && (role.try(:bookmark_url) != family_account_path)
      role.bookmark_url = bookmark_url
      role.try(:save!)
    elsif bookmark_url.match('/families/home') && @person.present?
      @person.consumer_role.update_attribute(:bookmark_url, family_account_path) if @person.consumer_role.present? && @person.consumer_role.bookmark_url != family_account_path
      @person.employee_roles.last.update_attribute(:bookmark_url, family_account_path) if @person.employee_roles.present? && @person.employee_roles.last.bookmark_url != family_account_path
    end
  end

  def set_bookmark_url(url = nil)
    set_current_person
    bookmark_url = url || request.original_url
    case bookmark_url
    when /employee/
      role = @person.try(:employee_roles).try(:last)
    when /consumer/
      role = @person.try(:consumer_role)
    end
    save_bookmark role, bookmark_url
  end

  def set_employee_bookmark_url(url = nil)
    set_current_person
    role = @person.try(:employee_roles).try(:last)
    bookmark_url = url || request.original_url
    save_bookmark role, bookmark_url
    session[:last_market_visited] = 'shop'
  end

  def set_consumer_bookmark_url(url = nil)
    set_current_person
    role = @person.try(:consumer_role)
    bookmark_url = url || request.original_url
    save_bookmark role, bookmark_url
    session[:last_market_visited] = 'individual'
  end

  def set_resident_bookmark_url(url = nil)
    set_current_person
    role = @person.try(:resident_role)
    bookmark_url = url || request.original_url
    save_bookmark role, bookmark_url
    session[:last_market_visited] = 'resident'
  end

  def stashed_user_password
    session["stashed_password"]
  end

  def authorize_for
    authorize(controller_name.classify.constantize, "#{action_name}?".to_sym)
  end

  def set_ie_flash_by_announcement
    return unless browser.ie? && !support_for_ie_browser?

    set_web_flash_by_announcement
  end

  def set_web_flash_by_announcement
    return unless flash.blank? || flash[:warning].blank?

    announcements = Announcement.get_announcements_for_web
    dismiss_announcements = begin
      JSON.parse(session[:dismiss_announcements] || "[]")
    rescue StandardError => e
      Rails.logger.error(e.message)
      []
    end
    announcements -= dismiss_announcements
    flash.now[:warning] = announcements
  end

  def set_flash_by_announcement
    return if current_user.blank?

    return unless flash.blank? || flash[:warning].blank?

    announcements = if current_user.has_hbx_staff_role?
                      Announcement.get_announcements_by_portal(request.path, @person)
                    else
                      current_user.get_announcements_by_roles_and_portal(request.path)
                    end
    dismiss_announcements = begin
      JSON.parse(session[:dismiss_announcements] || "[]")
    rescue StandardError
      Rails.logger.error(ex.message)
      []
    end
    announcements -= dismiss_announcements
    flash.now[:warning] = announcements
  end
end
