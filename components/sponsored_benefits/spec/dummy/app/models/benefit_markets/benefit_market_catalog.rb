# frozen_string_literal: true

module BenefitMarkets
  class BenefitMarketCatalog
    include Mongoid::Document
    include Mongoid::Timestamps

    # Frequency at which sponsors may submit an initial or renewal application
    # Example application interval kinds:
    #   DC Individual Market, Congress:
    #     :application_interval_kind => :annual
    #   MA GIC
    #     :application_interval_kind => :annual_with_midyear_initial
    #   DC/MA SHOP Market:
    #     :application_interval_kind => :monthly
    field :application_interval_kind,  type: Symbol

    # Effective date range during which associated benefits may be offered by sponsors
    # Example application periods:
    #   DC Individual Market Initial & Renewal, Congress:
    #     :application_period => Date.new(2018,1,1)..Date.new(2018,12,31)
    #   MA GIC
    #     :application_period => Date.new(2018,7,1)..Date.new(2019,6,30)
    #   DC/MA SHOP Market:
    #     :application_period => Date.new(2018,1,1)..Date.new(2018,12,31)
    field :application_period,          type: Range

    # Sponsor choices for length of time new members must wait before they're eligible to enroll
    field :probation_period_kinds,      type: Array, default: []

    field :title,                       type: String, default: ""
    field :description,                 type: String, default: ""

    delegate    :kind, to: :benefit_market, prefix: true

    belongs_to  :benefit_market,
                class_name: "BenefitMarkets::BenefitMarket",
                optional: true

    embeds_one  :sponsor_market_policy,
                class_name: "::BenefitMarkets::MarketPolicies::SponsorMarketPolicy"
    embeds_one  :member_market_policy,
                class_name: "::BenefitMarkets::MarketPolicies::MemberMarketPolicy"
    embeds_many :product_packages, as: :packagable,
                                   class_name: "::BenefitMarkets::Products::ProductPackage"

    # Entire geography covered by under this catalog
    has_and_belongs_to_many  :service_areas,
                             class_name: "::BenefitMarkets::Locations::ServiceArea"


    validates_presence_of :benefit_market, :application_interval_kind, :application_period, :probation_period_kinds

    validates :application_interval_kind,
              inclusion: { in: BenefitMarkets::APPLICATION_INTERVAL_KINDS, message: "%<value>s is not a valid application interval kind" },
              allow_nil: false

    validate :validate_probation_periods
    validate :unique_application_period_range

    scope :by_application_date,     ->(date){ where(:"application_period.min".lte => date, :"application_period.max".gte => date) }


    def kind
      benefit_market.kind
    end
  end
end