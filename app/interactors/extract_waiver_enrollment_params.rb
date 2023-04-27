# frozen_string_literal: true

class ExtractWaiverEnrollmentParams
  include Interactor

  def call
    context.waiver_enrollment_details = {}
    non_cart = [:dental, :health] - @context.cart.keys.sort
    return unless non_cart.present?


    non_cart.each do |kind|
      attrs = context[kind]
      next unless attrs[:selected_to_waive] == 'true'

      context.waiver_enrollment_details[kind] = attrs
    end
  end
end