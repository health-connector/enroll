# frozen_string_literal: true

class FindProduct
  include Interactor

  def call
    context.product = BenefitMarkets::Products::Product.find(context.params[:product_id])
  end
end