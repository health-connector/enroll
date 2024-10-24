module BenefitMarkets
  class Locations::RatingArea
    include Mongoid::Document
    include Mongoid::Timestamps

    field :active_year, type: Integer
    field :exchange_provided_code, type: String

    # The list of county-zip pairs covered by this rating area
    field :county_zip_ids, type: Array

    # This rating area may cover entire state(s), if it does,
    # specify which here.
    field :covered_states, type: Array

    has_many :premium_value_products,
             class_name: "BenefitMarkets::Products::PremiumValueProduct"

    validates_presence_of :active_year, allow_blank: false
    validates_presence_of :exchange_provided_code, allow_nil: false

    validate :location_specified

    index({county_zip_ids: 1})
    index({covered_state_codes: 1})
    index(
      {active_year: 1, exchange_provided_code: 1},
      {name: "rating_areas_exchange_provided_code_index"}
    )

    scope :by_year, ->(year) { where(active_year: year) }

    def location_specified
      if county_zip_ids.blank? && covered_states.blank?
        errors.add(:base, "a location covered by the rating area must be specified")
      end
      true
    end

    def self.rating_area_for(address, during: TimeKeeper.date_of_record)
      county_name = address.county.blank? ? "" : address.county.titlecase
      zip_code = address.zip
      state_abbrev = address.state.blank? ? "" : address.state.upcase
      
      county_zip_ids = ::BenefitMarkets::Locations::CountyZip.where(
        :zip => zip_code,
        :county_name => county_name,
        :state => state_abbrev
      ).map(&:id)
      
      # TODO FIX
      # raise "Multiple Rating Areas Returned" if area.count > 1
      
      self.where(
        "active_year" => during.year,
        "$or" => [
          {"county_zip_ids" => { "$in" => county_zip_ids }},
          {"covered_states" => state_abbrev}
        ]
      ).first
    end

    def human_exchange_provided_code
      exchange_provided_code.match(/(\d+)/)[1].to_i
    end
  end
end
