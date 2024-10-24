class RatingArea
  include Mongoid::Document
  include Config::AcaModelConcern

  field :zip_code, type: String
  field :county_name, type: String
  field :rating_area, type: String
  field :zip_code_in_multiple_counties, type: Mongoid::Boolean, default: false
  field :active_years, type: Array

  validates_presence_of :zip_code, :county_name, :rating_area, :zip_code_in_multiple_counties
  validates_uniqueness_of :zip_code, scope: [:county_name, :active_years]
  validates_uniqueness_of :county_name, scope: [:zip_code, :active_years]
  validates_inclusion_of :rating_area, :in => market_rating_areas, :allow_blank => false

  def self.find_counties_for(**attr)
    self.where(attr).pluck(:county_name)
  end

  def self.rating_area_for(address, proposal_for = TimeKeeper.date_of_record.year)
    zip_code = address.zip
    county_name = address.county
    area = where(zip_code: zip_code, county_name: county_name, :active_years => proposal_for)
    raise "Multiple Rating Areas Returned" if area.size > 1
    return nil if area.empty?
    area.first.rating_area
  end

  def self.find_zip_codes_for(**attr)
    self.where(**attr).pluck(:zip_code)
  end
end
