module IvlBenefitSponsors
  class IvlBenefitPackages::IvlBenefitPackage
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :ivl_benefit_application, class_name: "::IvlBenefitSponsors::IvlBenefitApplications::IvlBenefitApplication",
                inverse_of: :ivl_benefit_packages

    embeds_many :ivl_benefit_element_eligibility_groups,
                class_name: "::IvlBenefitSponsors::IvlBenefitEligibilityElementGroups::IvlBenefitEligibilityElementGroup"
  end
end
