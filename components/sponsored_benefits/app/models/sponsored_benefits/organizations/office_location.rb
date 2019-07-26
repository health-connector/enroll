module SponsoredBenefits
  module Organizations
    class OfficeLocation
      include Mongoid::Document

      embedded_in :plan_design_employer_profile, class_name: "SponsoredBenefits::BenefitSponsorships::PlanDesignEmployerProfile"

      field :is_primary, type: Boolean, default: true

      embeds_one :address, class_name:"SponsoredBenefits::Locations::Address", cascade_callbacks: true, validate: true
      accepts_nested_attributes_for :address, reject_if: :all_blank, allow_destroy: true
      embeds_one :phone, class_name:"SponsoredBenefits::Locations::Phone", cascade_callbacks: true, validate: true
      accepts_nested_attributes_for :phone, reject_if: :all_blank, allow_destroy: true

      validates_presence_of :address, class_name:"SponsoredBenefits::Locations::Address"

      alias_method :is_primary?, :is_primary

      def county
        address.present? ? address.county : ""
      end

      def zip
        address.present? ? address.zip : ""
      end

      def primary_or_branch?
        ['primary', 'branch'].include? address.kind if address.present?
      end
    end
  end
end
