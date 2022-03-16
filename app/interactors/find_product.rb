# frozen_string_literal: true

class FindProduct
  include Interactor

  def call
    context.product = BenefitMarkets::Products::Product.find(product_id)
  end

  def product_id
    context.params[:product_id]
  end

end