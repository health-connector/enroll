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

      ACTION_TYPES = [:change, :correction].freeze
      ACTION_KINDS = ['voluntary', 'non_payment'].freeze

      field :effective_period,        type: Range
      field :sequence_id,             type: Integer
      field :action_type,             type: Symbol
      field :action_kind,             type: String
      field :action_reason,           type: String
      field :updated_by,              type: String
      field :state,                   type: Symbol
      field :action_on,               type: Date

      validates_presence_of :sequence_id, :effective_period, :state
      validates :action_type, inclusion: { in: ACTION_TYPES }, allow_blank: true
      validates :action_kind, inclusion: { in: ACTION_KINDS }, allow_blank: true
      validates :action_reason, inclusion: { in: VOLUNTARY_TERM_REASONS + NON_PAYMENT_TERM_REASONS }, allow_blank: true
    end
  end
end
