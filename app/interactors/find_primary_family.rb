# frozen_string_literal: true

class FindPrimaryFamily
  include Interactor

  before do
    context.fail!(message: "missing person") unless context.person.present?
  end

  def call
    primary_family = context.person.primary_family

    if primary_family
      context.primary_family = primary_family
    else
      context.fail!(message: "no primary family found")
    end
  end
end