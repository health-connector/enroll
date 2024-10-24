module SponsoredBenefits
  class RatingTierClassification
    field :is_default, type: Mongoid::Boolean, default: false
    field :required_relationships, type: Array[String]
    belongs_to :rating_tier
  end
end
