# frozen_string_literal: true

class SelectMarketKind
  include Interactor

  before do
    context.fail!(message: "cannot set market kind without person") if person.blank?
  end

  def call
    context.market_kind = select_market(context.params)
  end

  private

  def select_market(params)
    return params[:market_kind] if params[:market_kind].present?

    if params[:qle_id].present? && !person.has_active_resident_role?
      qle = QualifyingLifeEventKind.find(params[:qle_id])
      return qle.market_kind
    end

    if person.has_active_employee_role?
      'shop'
    elsif person.has_active_consumer_role? && !person.has_active_resident_role?
      'individual'
    elsif person.has_active_resident_role?
      'coverall'
    end
  end

  def person
    @person ||= context.person
  end
end