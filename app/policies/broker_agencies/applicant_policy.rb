# frozen_string_literal: true

module BrokerAgencies
  class ApplicantPolicy < ApplicationPolicy

    def index?
      check_primary_broker_role
    end

    def edit?
      check_primary_broker_role
    end

    def update?
      check_primary_broker_role
    end

    private

    def check_primary_broker_role
      return true if shop_market_admin?

      person = account_holder&.person
      return true if person&.broker_role&.is_primary_broker?

      false
    end
  end
end