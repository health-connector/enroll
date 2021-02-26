# frozen_string_literal: true

module BenefitSponsors
  module ClientContributionUnitSpecHelpers
    module CCA
      def build_contribution_units(ee_min_contribution_factor, dep_min_contribution_factor)
        [
          {
            "_id" => BSON::ObjectId.new,
            "_type" => "BenefitMarkets::ContributionModels::FixedPercentContributionUnit",
            "minimum_contribution_factor" => ee_min_contribution_factor,
            "name" => "employee",
            "display_name" => "Employee",
            "order" => 0,
            "default_contribution_factor" => 0.0,
            "member_relationship_maps" => [{"_id" => BSON::ObjectId.new, "operator" => :==, "relationship_name" => :employee, "count" => 1}]
          },
          {
            "_id" => BSON::ObjectId.new,
            "_type" => "BenefitMarkets::ContributionModels::FixedPercentContributionUnit",
            "minimum_contribution_factor" => dep_min_contribution_factor,
            "name" => "spouse",
            "display_name" => "Spouse",
            "order" => 1,
            "default_contribution_factor" => 0.0,
            "member_relationship_maps" => [{ "_id" => BSON::ObjectId.new, "operator" => :>=, "relationship_name" => :spouse, "count" => 1 }]
          },
          {
            "_id" => BSON::ObjectId.new,
            "_type" =>
            "BenefitMarkets::ContributionModels::FixedPercentContributionUnit",
            "minimum_contribution_factor" => dep_min_contribution_factor,
            "name" => "domestic_partner",
            "display_name" => "Domestic Partner",
            "order" => 2,
            "default_contribution_factor" => 0.0,
            "member_relationship_maps" => [{ "_id" => BSON::ObjectId.new, "operator" => :>=, "relationship_name" => :domestic_partner, "count" => 1 }]
          },
          {
            "_id" => BSON::ObjectId.new,
            "_type" =>
            "BenefitMarkets::ContributionModels::FixedPercentContributionUnit",
            "minimum_contribution_factor" => dep_min_contribution_factor,
            "name" => "dependent",
            "display_name" => "Child Under 26",
            "order" => 3,
            "default_contribution_factor" => 0.0,
            "member_relationship_maps" => [{"_id" => BSON::ObjectId.new, "operator" => :>=, "relationship_name" => :dependent, "count" => 1}]
          }
        ]
      end
    end
  end
end