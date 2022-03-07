# frozen_string_literal: true

class DisableMarketKinds
  include Interactor

  def call
    context.disable_market_kind = disable_market_kind(context.params)
  end

  private

  def disable_market_kind(params)
    if context.change_plan == 'change_by_qle' || context.enrollment_kind == 'sep'
      select_market(params) == "shop" ? "individual" : "shop"
    end
  end

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
    context.person
  end
end