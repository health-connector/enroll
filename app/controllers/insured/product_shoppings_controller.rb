# frozen_string_literal: true

module Insured
  class ProductShoppingsController < ApplicationController

    before_action :set_current_person, :only => [:receipt, :thankyou, :waive, :continuous_show, :checkout, :terminate]

    # rubocop:disable Metrics/CyclomaticComplexity
    def continuous_show
      attr = params.deep_symbolize_keys
      @context = Organizers::FetchProductsForShoppingEnrollment.call(health: attr[:health], dental: attr[:dental], cart: attr[:cart],
                                                                     dental_offering: attr[:dental_offering],  health_offering: attr[:health_offering],
                                                                     action: attr[:action], event: attr[:event])

      if @context.failure?
        flash[:error] = @context.message
        redirect_to family_account_path
        return
      end
      set_employee_bookmark_url(family_account_path)

      # TODO: check for values and move to interractor
      if @context.shop_attributes.present?
        @context.change_plan = @context.shop_attributes[:change_plan] || ''
        @context.enrollment_kind = @context.shop_attributes[:enrollment_kind] || ''
      end

      if @context.shop_for.nil? && @context.go_to_coverage_selection == false
        redirect_to thankyou_insured_product_shoppings_path(cart: @context.cart, event: @context.event)
        return
      elsif @context.go_to_coverage_selection == true
        mini_context_hash = ExtractContinuousShoppingParams.call(cart: @context.cart.to_h)
        coverage_hash = @context&.health || @context&.dental
        @mini_context = mini_context_hash.to_h.merge!(coverage_for: @context.coverage_for, change_plan: coverage_hash[:change_plan])
        ExtractWaiverEnrollmentParams.call(@context)
        render 'eligible_continuous_coverage'
      else
        render :show
      end

      ::Caches::CustomCache.release(::BenefitSponsors::Organizations::Organization, :plan_shopping)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def thankyou
      @context = params[:cart].each_with_object({}) do |(k,v),output|
        context = Organizers::PrepareForCheckout.call(params: v, person: @person, event: params[:event])
        output[k] = context.json
      end

      @waiver_context = if params[:waiver_attrs].present?
                          params[:waiver_attrs].each_with_object({}) do |(k,v),output|
                            context = Organizers::PrepareForWaiverCheckout.call(params: v, person: @person, event: params[:event])
                            output[k] = context.json
                          end
                        else
                          {}
                        end

      @context = Hash[@context.sort.reverse]
      set_consumer_bookmark_url(family_account_path)

      respond_to do |format|
        format.html { render 'thankyou.html.erb' }
      end
    end

    def checkout
      @context = params.except("_method", "authenticity_token", "controller", "action", "waiver_context").each_with_object({}) do |(key,value), output|
        context = Organizers::Checkout.call(params: value, previous_enrollment_id: session[:pre_hbx_enrollment_id])
        output[key] = context.json
      end

      @waiver_context = if params['waiver_context'].present?
                          params['waiver_context'].each_with_object({}) do |(k, v), output|
                            context = Organizers::WaiveEnrollment.call(hbx_enrollment_id: v[:enrollment_id], waiver_reason: v[:waiver_reason])
                            output[k] = {waiver_status: context.waiver_enrollment.inactive?, waiver_enrollment: context.waiver_enrollment}
                          end
                        else
                          {}
                        end

      @context.merge!("waiver_context" => @waiver_context)
      @context = Hash[@context.sort.reverse]

      if @context.values.select{|hash| hash[:employee_is_shopping_before_hire]}.any?(true)
        session.delete(:pre_hbx_enrollment_id)
        flash[:error] = "You are attempting to purchase coverage prior to your date of hire on record. Please contact your Employer for assistance"
        redirect_to family_account_path
        return
      end

      if @context.values.select{|hash| hash[:can_select_coverage]}.any?(false)
        redirect_to :back
        return
      end

      session.delete(:pre_hbx_enrollment_id)
      redirect_to receipt_insured_product_shoppings_path(@context)
    end

    def receipt
      @context = params.except("_method", "authenticity_token", "controller","action", "waiver_context").each_with_object({}) do |(key,value), output|
        context = Organizers::Receipt.call(params: value, previous_enrollment_id: session[:pre_hbx_enrollment_id])
        output[key] = context
      end

      if params["waiver_context"].present?
        @health_waiver = (HbxEnrollment.find(params["waiver_context"]['health']['waiver_enrollment']) if params["waiver_context"]['health'].present?)

        @dental_waiver = (HbxEnrollment.find(params["waiver_context"]['dental']['waiver_enrollment']) if params["waiver_context"]['dental'].present?)
      end

      @context = Hash[@context.sort.reverse]

      #TODO
      # @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
      # @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''

      # send_receipt_emails if @person.emails.first
    end

    def waiver_thankyou
      attrs = params.deep_symbolize_keys
      enr_details = attrs.slice(:health, :dental)
      @context = enr_details.each_with_object({}) do |(k,v),output|
        context = Organizers::PrepareForWaiverCheckout.call(params: v, person: @person, event: attrs[:event])
        output[k] = context.json
      end

      @context = Hash[@context.sort.reverse]
      set_consumer_bookmark_url(family_account_path)

      respond_to do |format|
        format.html { render 'waiver_thankyou.html.erb' }
      end
    end

    def waiver_checkout
      @context = params.except("_method", "authenticity_token", "controller","action").each_with_object({}) do |(key,value), output|
        context = Organizers::WaiveEnrollment.call(hbx_enrollment_id: value[:enrollment_id], waiver_reason: value[:waiver_reason])
        output[key] = {waiver_status: context.waiver_enrollment.inactive?, waiver_enrollment: context.waiver_enrollment}
      end
      @context = Hash[@context.sort.reverse]
      session.delete(:pre_hbx_enrollment_id)

      redirect_to waiver_receipt_insured_product_shoppings_path(@context), notice: 'Waive Coverage Successful'
    end

    def waiver_receipt
      @health_enrollment = params[:health].present? ? HbxEnrollment.find(params[:health][:waiver_enrollment]) : nil
      @dental_enrollment = params[:dental].present? ? HbxEnrollment.find(params[:dental][:waiver_enrollment]) : nil
    end

    def waive
      context = Organizers::WaiveEnrollment.call(hbx_enrollment_id: params[:id], waiver_reason: params[:waiver_reason])

      if context.waiver_enrollment.inactive?
        redirect_to print_waiver_insured_plan_shopping_path(context.waiver_enrollment), notice: 'Waive Coverage Successful'
      else
        redirect_to new_insured_members_selection_path(person_id: @person.id, change_plan: 'change_plan', hbx_enrollment_id: context.hbx_enrollment.id), alert: 'Waive Coverage Failed'
      end
    rescue StandardError => e
      log(e.message, :severity => 'error')
      redirect_to new_insured_members_selection_path(person_id: @person.id, change_plan: 'change_plan', hbx_enrollment_id: context.hbx_enrollment.id), alert: 'Waive Coverage Failed'
    end

    def print_waiver
      @hbx_enrollment = HbxEnrollment.find(params.require(:id))
    end

    private

    def sanatize_params(param)
      if param.instance_of?(Hash)
        param
      elsif param.instance_of?(String)
        JSON.parse(param)
      end
    end

    def send_receipt_emails
      UserMailer.generic_consumer_welcome(@person.first_name, @person.hbx_id, @person.emails.first.address).deliver_now
      body = render_to_string 'user_mailer/secure_purchase_confirmation.html.erb', layout: false
      from_provider = HbxProfile.current_hbx
      message_params = {
        sender_id: from_provider.try(:id),
        parent_message_id: @person.id,
        from: from_provider.try(:legal_name),
        to: @person.full_name,
        body: body,
        subject: 'Your Secure Enrollment Confirmation'
      }
      create_secure_message(message_params, @person, :inbox)
    end
  end
end
