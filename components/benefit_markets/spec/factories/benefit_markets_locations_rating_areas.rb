# frozen_string_literal: true

FactoryBot.define do
  factory :benefit_markets_locations_rating_area, class: 'BenefitMarkets::Locations::RatingArea' do

    active_year { TimeKeeper.date_of_record.year }
    exchange_provided_code { "R-#{Settings.aca.state_abbreviation}001" }
    # These should never occur at the same time
    covered_states { ["MA"] }
    county_zip_ids { [create(:benefit_markets_locations_county_zip, county_name: 'Middlesex', zip: '01754', state: 'MA').id] }
  end
end
