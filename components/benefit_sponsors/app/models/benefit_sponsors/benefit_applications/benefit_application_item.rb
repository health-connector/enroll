# frozen_string_literal: true

module BenefitSponsors
  module BenefitApplications
    class BenefitApplicationItem
      include Mongoid::Document
      include Mongoid::Timestamps

      embedded_in :benefit_application,
                  class_name: "::BenefitSponsors::BenefitApplications::BenefitApplication",
                  inverse_of: :benefit_application_items

      VOLUNTARY_TERM_REASONS = [
        "Company went out of business/bankrupt",
        "Customer Service did not solve problem/poor experience",
        "Connector website too difficult to use/navigate",
        "Health Connector does not offer desired product",
        "Group is now > 50 lives",
        "Group no longer has employees",
        "Went to carrier directly",
        "Went to an association directly",
        "Added/changed broker that does not work with Health Connector",
        "Company is no longer offering insurance",
        "Company moved out of Massachusetts",
        "Other"
      ].freeze

      NON_PAYMENT_TERM_REASONS = [
        "Non-payment of premium"
      ].freeze

      ITEM_TYPES = [:change, :correction].freeze

      field :effective_period,        type: Range
      field :sequence_id,             type: Integer
      field :item_type,               type: Symbol
      field :item_type_reason,        type: String
      field :updated_by,              type: String
      field :state,           type: Symbol

      validates_presence_of :sequence_id, :effective_period, :state
    end
  end
end