module IvlBenefitSponsors
  class IvlBenefitApplications::IvlBenefitApplication
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :benefit_sponsorship,
                class_name: "::BenefitSponsors::BenefitSponsorships::BenefitSponsorship",
                inverse_of: :ivl_benefit_applications

    embeds_many :ivl_benefit_packages,
                class_name: "::IvlBenefitSponsors::IvlBenefitPackages::IvlBenefitPackage"

    # The date range when this application is active
    field :effective_period,        type: Range

    # The date range when members may enroll
    field :open_enrollment_period,  type: Range

    # The date on which this application was canceled or terminated
    field :terminated_on,           type: Date

    # Second Lowest Cost Silver Plan, by rating area (only one rating area in DC)
    field :slcsp, type: BSON::ObjectId
    field :slcsp_id, type: BSON::ObjectId

    # This IvlBenefitApplication's name
    field :title, type: String

    before_save :set_title

    validates_presence_of :effective_period, :open_enrollment_period, message: "is invalid"

    def effective_period=(new_effective_period)
      effective_range = IvlBenefitSponsors.tidy_date_range(new_effective_period, :effective_period)
      super(effective_range) if effective_range.present?
    end

    def open_enrollment_period=(new_open_enrollment_period)
      open_enrollment_range = ::IvlBenefitSponsors.tidy_date_range(new_open_enrollment_period, :open_enrollment_period)
      super(open_enrollment_range) if open_enrollment_range.present?
    end

    private

    def set_title
      return if title.present?
      self.title = "Individual Market Benefits #{effective_period.min.year}"
    end

    # def end_date_follows_start_date
    #   return unless self.end_on.present?
    #   # Passes validation if end_on == start_date
    #   errors.add(:end_on, "end_on cannot preceed start_on date") if self.end_on < self.start_on
    # end
  end
end
