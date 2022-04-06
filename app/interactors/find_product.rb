# frozen_string_literal: true

class FindProduct
  include Interactor

  before do
    context.fail!(message: "Invalid product id") if product_id.nil?
  end

  def call
    context.product = product
  end

  private

  def product
    @product ||= BenefitMarkets::Products::Product.find(product_id)
  rescue Mongoid::Errors::DocumentNotFound => _e
    context.fail!(message: "No product found")
  end

  def product_id
    context.params[:product_id]
  end
end