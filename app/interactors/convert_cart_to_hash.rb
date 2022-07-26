# frozen_string_literal: true

class ConvertCartToHash
  include Interactor

  def call
    cart = context.params[:cart]
    return unless cart

    context.params[:cart] = if cart.class == Hash
                              cart
                            elsif cart.class == String
                              JSON.parse(cart.gsub('=>', ":"))
                            end
  rescue StandardError => _e
    context.fail!(message: "invalid Cart")
  end
end