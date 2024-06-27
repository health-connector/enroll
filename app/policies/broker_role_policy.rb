# frozen_string_literal: true

class BrokerRolePolicy < ApplicationPolicy

  def build_employee_roster?
    show?
  end

  def copy?
    show?
  end

  def create?
    show?
  end

  def criteria?
    show?
  end

  def delete_benefit_group?
    show?
  end

  def delete_household?
    show?
  end

  def delete_member?
    show?
  end

  def delete_quote?
    show?
  end

  def delete_quote_modal?
    show?
  end

  def dental_cost_comparison?
    show?
  end

  def dental_plans_data?
    show?
  end

  def download_employee_roster?
    show?
  end

  def download_pdf?
    show?
  end

  def edit?
    show?
  end

  def employees_list?
    show?
  end

  def employee_type?
    show?
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_quote_info?
    show?
  end
  # rubocop:enable Naming/AccessorMethodName

  def health_cost_comparison?
    show?
  end

  def my_quotes?
    show?
  end

  def new?
    show?
  end

  def new_household?
    show?
  end

  def plan_comparison?
    show?
  end

  def publish?
    show?
  end

  def publish_quote?
    show?
  end

  def set_plan?
    show?
  end

  def show?
    return false unless account_holder_person
    return true if shop_market_admin?
    return true if account_holder_person.broker_role&.active?
    return true if account_holder_person.broker_agency_staff_roles&.active.present?

    false
  end

  def update?
    show?
  end

  def update_benefits?
    show?
  end

  def upload_employee_roster?
    show?
  end

end
