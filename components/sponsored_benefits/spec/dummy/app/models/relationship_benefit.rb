class RelationshipBenefit
  include Mongoid::Document

  embedded_in :benefit_group

  field :relationship, type: String
  field :premium_pct, type: Float, default: 0.0
  field :offered, type: Mongoid::Boolean, default: true
  field :employer_max_amt, type: Float, default: 0.0
end
