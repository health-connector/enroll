# frozen_string_literal: true

module Insured
  class ProductShoppingsController < ApplicationController

    before_action :set_current_person, :only => [:receipt, :thankyou, :waive, :continuous_show, :checkout, :terminate]

    def continuous_show
      @context = Organizers::FetchProductsForShoppingEnrollment.call(health: params[:health]&.deep_symbolize_keys, dental: params[:dental]&.deep_symbolize_keys, cart: params[:cart]&.deep_symbolize_keys)
      set_employee_bookmark_url(family_account_path)

      if @context.shop_attributes.present?
        @context.change_plan = @context.shop_attributes[:change_plan] || ''
        @context.enrollment_kind = @context.shop_attributes[:enrollment_kind] || ''
      end

      if @context.shop_for.nil? && @context.go_to_coverage_selection == false
        redirect_to thankyou_insured_product_shoppings_path(@context.cart)
      else
        render :show
      end

      ::Caches::CustomCache.release(::BenefitSponsors::Organizations::Organization, :plan_shopping)
    end

    def thankyou
      @context = params.except(:controller,:action).each_with_object({}) do |(k,v),output|
        context = Organizers::PrepareForCheckout.call(params: v, person: @person)
        output[k] = context.json
      end

      set_consumer_bookmark_url(family_account_path)


      @change_plan = params[:change_plan].present? ? params[:change_plan] : ''
      @enrollment_kind = params[:enrollment_kind].present? ? params[:enrollment_kind] : ''

      respond_to do |format|
        format.html { render 'thankyou.html.erb' }
      end
    end
  end
end
