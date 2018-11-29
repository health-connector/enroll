module IvlBenefitSponsors
  class IvlBenefitApplications::IvlBenefitApplication
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :benefit_sponsorship,
                class_name: "::BenefitSponsors::BenefitSponsorships::BenefitSponsorship",
                inverse_of: :ivl_benefit_applications

    embeds_many :ivl_benefit_packages,
                class_name: "::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage"

  end
end
