# frozen_string_literal: true

class FindPrimaryFamily
  include Interactor

  before do
    context.fail!(message: "missing person") unless context.person.present?
  end

  def call
    context.primary_family = context.person.primary_family
  end
end