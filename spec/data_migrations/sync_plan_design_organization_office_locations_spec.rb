# frozen_string_literal: true

require "rails_helper"

require File.join(Rails.root, "app", "data_migrations", "sync_plan_design_organization_office_locations")

describe SyncPlanDesignOrganizationOfficeLocations, dbclean: :after_each do
  subject { SyncPlanDesignOrganizationOfficeLocations.new("sync_plan_design_organization_office_locations", double(:current_scope => nil)) }

  let(:site)             { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:organization)     { create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:employer_profile) { organization.employer_profile }

  def plan_design_organization_with(sponsor_profile_id:, zip:, county:)
    office_location = build(:sponsored_benefits_office_location, :primary)
    office_location.address.assign_attributes(zip: zip, county: county)
    create(:sponsored_benefits_plan_design_organization, sponsor_profile_id: sponsor_profile_id, owner_profile_id: BSON::ObjectId.new,
                                                         sic_code: "0345", office_locations: [office_location])
  end

  def primary_address_of(plan_design_organization)
    plan_design_organization.reload.primary_office_location.address
  end

  it "copies the employer's address onto a plan design organization with an old address" do
    employer_address = employer_profile.primary_office_location.address
    plan_design_organization = plan_design_organization_with(sponsor_profile_id: employer_profile.id, zip: '02155', county: 'Middlesex')

    subject.migrate

    expect(primary_address_of(plan_design_organization).zip).to eq employer_address.zip
    expect(primary_address_of(plan_design_organization).county).to eq employer_address.county
  end

  it "does not touch a plan design organization that already matches its employer" do
    plan_design_organization = create(:sponsored_benefits_plan_design_organization, sponsor_profile_id: employer_profile.id, owner_profile_id: BSON::ObjectId.new,
                                                                                    sic_code: "0345", office_locations: employer_profile.office_locations.map { |location| location.attributes.deep_dup })

    expect { subject.migrate }.not_to(change { plan_design_organization.reload.updated_at })
  end

  it "does not touch a prospect" do
    prospect = plan_design_organization_with(sponsor_profile_id: nil, zip: '02155', county: 'Middlesex')

    subject.migrate

    expect(primary_address_of(prospect).zip).to eq '02155'
  end
end
