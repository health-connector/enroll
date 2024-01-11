class Exchanges::EmployerApplicationsController < ApplicationController
  include Pundit
  include Config::AcaHelper
  include L10nHelper

  before_action :can_modify_plan_year?, only: [:terminate, :cancel, :reinstate, :revise_end_date]
  before_action :check_hbx_staff_role, except: :get_term_reasons
  before_action :find_benefit_sponsorship, except: :get_term_reasons

  def index
    @allow_mid_month_voluntary_terms = allow_mid_month_voluntary_terms?
    @allow_mid_month_non_payment_terms = allow_mid_month_non_payment_terms?
    @element_to_replace_id = params[:employers_action_id]
  end

  def terminate
    @application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
    end_on = Date.strptime(params[:end_on], "%m/%d/%Y")
    termination_kind = params['term_kind']
    termination_reason = params['term_reason']
    transmit_to_carrier = params['transmit_to_carrier'] == "true" || params['transmit_to_carrier'] == true ? true : false
    @service = BenefitSponsors::Services::BenefitApplicationActionService.new(@application, {
                                                                                end_on: end_on,
                                                                                termination_kind: termination_kind,
                                                                                termination_reason: termination_reason,
                                                                                transmit_to_carrier: transmit_to_carrier,
                                                                                current_user: current_user
                                                                              })
    result, application, errors = @service.terminate_application

    item = @application.reload.latest_benefit_application_item
    confirmation_payload = { employer_id: @benefit_sponsorship.id, employer_application_id: @application.id, sequence_id: item.sequence_id}
    confirmation_payload.merge!({errors: errors.values}) unless result
    redirect_to confirmation_details_exchanges_employer_applications_path(confirmation_payload)
  end

  def cancel
    @application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
    transmit_to_carrier = params['transmit_to_carrier'] == "true" || params['transmit_to_carrier'] == true ? true : false
    @service = BenefitSponsors::Services::BenefitApplicationActionService.new(@application, { transmit_to_carrier: transmit_to_carrier, current_user: current_user })
    result, application, errors = @service.cancel_application

    item = @application.reload.latest_benefit_application_item
    confirmation_payload = { employer_id: @benefit_sponsorship.id, employer_application_id: @application.id, sequence_id: item.sequence_id}
    confirmation_payload.merge!({errors: errors.values}) unless result
    redirect_to confirmation_details_exchanges_employer_applications_path(confirmation_payload)
  end

  def get_term_reasons
    @reasons = if params[:reason_type_id] == "term_actions_nonpayment"
                 BenefitSponsors::BenefitApplications::BenefitApplicationItem::NON_PAYMENT_TERM_REASONS
               else
                 BenefitSponsors::BenefitApplications::BenefitApplicationItem::VOLUNTARY_TERM_REASONS
               end
    render json: @reasons
  end

  def application_history
    if ::EnrollRegistry.feature_enabled?(:benefit_application_history)
      @application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
    else
      redirect_to exchanges_hbx_profiles_root_path
    end
  end

  def confirmation_details
    @application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
    required_details = {
      benefit_sponsorship: @benefit_sponsorship,
      benefit_application: @application,
      sequence_id: params[:sequence_id]
    }
    required_details.merge!({errors: params[:errors]}) if params[:errors].present?

    result = BenefitSponsors::Operations::BenefitApplications::ConfirmationDetails.new.call(required_details)
    if result.success?
      @result = result.value!
    else
      @failures = result.failure.is_a?(Array) ? result.failure : [result.failure]
    end
  end

  def reinstate
    if ::EnrollRegistry.feature_enabled?(:benefit_application_reinstate)
      application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
      transmit_to_carrier = params['transmit_to_carrier'] == "true"
      reinstate_on = if params[:reinstate_on]
                       Date.strptime(params[:reinstate_on], "%m/%d/%Y")
                     else
                       application.retroactive_canceled? ? application.start_on : (application.end_on + 1.day)
                     end

      result = BenefitSponsors::Operations::BenefitApplications::Reinstate.new.call({
                                                                                      benefit_application: application,
                                                                                      transmit_to_carrier: transmit_to_carrier,
                                                                                      reinstate_on: reinstate_on,
                                                                                      current_user: current_user
                                                                                    })

      item = application.reload.latest_benefit_application_item
      confirmation_payload = { employer_id: @benefit_sponsorship.id, employer_application_id: application.id, sequence_id: item.sequence_id}
      confirmation_payload.merge!({errors: result.failure}) if result.failure?
      redirect_to confirmation_details_exchanges_employer_applications_path(confirmation_payload)
    else
      redirect_to exchanges_hbx_profiles_root_path
    end
  rescue StandardError => e
    Rails.logger.error { "#{application.benefit_sponsorship.legal_name} - #{l10n('exchange.employer_applications.unable_to_reinstate')} - #{e.backtrace}" }
    redirect_to exchanges_hbx_profiles_root_path, flash[:error] => "#{application.benefit_sponsorship.legal_name} - #{l10n('exchange.employer_applications.unable_to_reinstate')}"
  end

  def revise_end_date
    if ::EnrollRegistry.feature_enabled?(:benefit_application_revise_end_date)
      application = @benefit_sponsorship.benefit_applications.find(params[:employer_application_id])
      transmit_to_carrier = params['transmit_to_carrier'] == "true"
      term_date = Date.strptime(params[:revise_end_date], "%m/%d/%Y")
      reinstate_on = application.retroactive_canceled? ? application.start_on : (application.end_on + 1.day)

      result = BenefitSponsors::Operations::BenefitApplications::Revise.new.call({
                                                                                   benefit_application: application,
                                                                                   transmit_to_carrier: transmit_to_carrier,
                                                                                   reinstate_on: reinstate_on,
                                                                                   current_user: current_user,
                                                                                   term_date: term_date,
                                                                                   termination_kind: application.termination_kind,
                                                                                   termination_reason: application.termination_reason
                                                                                 })
      item = application.reload.latest_benefit_application_item
      confirmation_payload = { employer_id: @benefit_sponsorship.id, employer_application_id: application.id, sequence_id: item.sequence_id}
      confirmation_payload.merge!({errors: result.failure}) if result.failure?
      redirect_to confirmation_details_exchanges_employer_applications_path(confirmation_payload)
    end
  rescue StandardError => e
    Rails.logger.error { "#{application.benefit_sponsorship.legal_name} - #{l10n('exchange.employer_applications.unable_to_change_end_date')} - #{e.backtrace}" }
    redirect_to exchanges_hbx_profiles_root_path, flash[:error] => "#{application.benefit_sponsorship.legal_name} - #{l10n('exchange.employer_applications.unable_to_change_end_date')}"
  end

  private

  def can_modify_plan_year?
    authorize HbxProfile, :can_modify_plan_year?
  end

  def check_hbx_staff_role
    redirect_to root_path, :flash => { :error => "You must be an HBX staff member" } unless current_user.has_hbx_staff_role?
  end

  def find_benefit_sponsorship
    @benefit_sponsorship = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.find(params[:employer_id])
  end
end
