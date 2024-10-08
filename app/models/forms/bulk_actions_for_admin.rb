module Forms
  class BulkActionsForAdmin
    include Acapi::Notifiers

    attr_reader :result
    attr_reader :row
    attr_reader :family_id
    attr_reader :params
    attr_reader :config

    def initialize(*arguments)
      @params = arguments.extract_options!
      @result = {success: [], failure: []}
      @row = @params[:family_actions_id]
      @family_id = @params[:family_id]
      @config = Rails.application.config.acapi
    end

    def cancel_enrollments
      cancelled_enrollments_transmission_info = {}
      @params.each do |key, value|
        if key.to_s[/cancel_hbx_.*/]
          hbx = HbxEnrollment.find(params[key.to_s])
          begin
            hbx.cancel_coverage! if hbx.may_cancel_coverage?
            @result[:success] << hbx
            cancelled_enrollments_transmission_info[hbx.id] = params.key?("transmit_hbx_#{hbx.id.to_s}") ? true : false
          rescue
            @result[:failure] << hbx
          end
        end
      end
      cancelled_enrollments_transmission_info.each { |hbx_id, transmit_flag| handle_edi_transmissions(hbx_id, transmit_flag) }
    end

    def terminate_enrollments
      terminated_enrollments_transmission_info = {}
      @params.each do |key, value|
        if key.to_s[/terminate_hbx_.*/]
          hbx = HbxEnrollment.find(params[key.to_s])
          begin
            termination_date = Date.strptime(params["termination_date_#{value}"], "%m/%d/%Y")
            hbx.terminate_coverage!(termination_date) if hbx.may_terminate_coverage?
            @result[:success] << hbx
            terminated_enrollments_transmission_info[hbx.id] = params.key?("transmit_hbx_#{hbx.id.to_s}") ? true : false
          rescue
            @result[:failure] << hbx
          end
        end
      end
      terminated_enrollments_transmission_info.each { |hbx_id, transmit_flag| handle_edi_transmissions(hbx_id, transmit_flag) }
    end

    private

    def eligible_to_transmit(hbx)
      return true unless hbx.is_shop? || hbx.sponsored_benefit_package_id.present?

      benefit_package = hbx.sponsored_benefit_package
      benefit_application = benefit_package.benefit_application
      quiet_period = benefit_application.enrollment_quiet_period
      transition_at = hbx.workflow_state_transitions.where(:to_state.in => ["coverage_terminated","coverage_canceled", "coverage_termination_pending"]).last.transition_at
      ["enrollment_eligible", "active", "terminated","expired", "termination_pending"].include?(benefit_application.aasm_state.to_s) && transition_at.in_time_zone("UTC") >= quiet_period.max
    end

    def handle_edi_transmissions(hbx_id, transmit_flag) #transmit_flag = true/false based on wheather the user elected to transmit.
      hbx = HbxEnrollment.find(hbx_id)
      ### Handle EDI transmission here ###

      return true unless eligible_to_transmit(hbx)

      notify(
        "acapi.info.events.hbx_enrollment.terminated",
        {
          :reply_to => "#{config.hbx_id}.#{config.environment_name}.q.glue.enrollment_event_batch_handler",
          "hbx_enrollment_id" => hbx.hbx_id,
          "enrollment_action_uri" => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
          "is_trading_partner_publishable" => transmit_flag
        }
      )
    end
  end
end
