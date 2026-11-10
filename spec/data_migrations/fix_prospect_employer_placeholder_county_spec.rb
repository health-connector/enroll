# frozen_string_literal: true

require "rails_helper"

require File.join(Rails.root, "app", "data_migrations", "fix_prospect_employer_placeholder_county")

describe FixProspectEmployerPlaceholderCounty, dbclean: :after_each do
  subject { FixProspectEmployerPlaceholderCounty.new("fix_prospect_employer_placeholder_county", double(:current_scope => nil)) }

  let!(:county_zip) { create(:benefit_markets_locations_county_zip, zip: '01060', county_name: 'Hampshire') }

  def prospect_with(zip:, county:)
    office_location = build(:sponsored_benefits_office_location, :primary)
    office_location.address.assign_attributes(zip: zip, county: county)
    create(:sponsored_benefits_plan_design_organization, sponsor_profile_id: nil, office_locations: [office_location])
  end

  def county_of(organization)
    organization.reload.office_locations.first.address.county
  end

  it "sets the county for a prospect saved with the placeholder" do
    prospect = prospect_with(zip: '01060', county: 'Please provide a zip code')
    subject.migrate
    expect(county_of(prospect)).to eq 'Hampshire'
  end

  it "leaves a prospect alone when its zip has more than one county" do
    create(:benefit_markets_locations_county_zip, zip: '01060', county_name: 'Franklin')
    prospect = prospect_with(zip: '01060', county: 'Please provide a zip code')
    subject.migrate
    expect(county_of(prospect)).to eq 'Please provide a zip code'
  end

  it "does not touch a prospect with a valid county" do
    prospect = prospect_with(zip: '01060', county: 'Hampshire')
    expect { subject.migrate }.not_to(change { prospect.reload.updated_at })
  end
end
