module IvlBenefitSponsors
  class IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :ivl_benefit_package,
                class_name: "::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage"
  end
end
