# frozen_string_literal: true

class FindProduct
  include Interactor

  before do
    context.fail!(message: "no product found") if product.blank?
  end

  def call
    context.product = product
  end

  private

  def product
    @product ||= BenefitMarkets::Products::Product.find(product_id)
  end

  def product_id
    context.params[:product_id]
  end
end