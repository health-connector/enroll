 # frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_site_spec_helpers"
require "#{BenefitSponsors::Engine.root}/spec/support/benefit_sponsors_product_spec_helpers"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module Effective
  module Datatables
    RSpec.describe BenefitSponsorsEmployerDatatable, type: :model do
      #include_context "setup benefit market with market catalogs and product packages"
      #include_context "setup initial benefit application"
      # let(:user)                            { double(:user, has_hbx_staff_role?: true, last_portal_visited: "www.google.com")}
      # let(:valid_session)                   { {} }
      let(:site)                            { ::BenefitSponsors::Site.all.first || ::BenefitSponsors::SiteSpecHelpers.create_cca_site_with_hbx_profile_and_benefit_market }
      let!(:previous_rating_area)           { create_default(:benefit_markets_locations_rating_area, active_year: Date.current.year - 1) }
      let!(:previous_service_area)          { create_default(:benefit_markets_locations_service_area, active_year: Date.current.year - 1) }
      let!(:rating_area)                    { create_default(:benefit_markets_locations_rating_area) }
      let!(:service_area)                   { create_default(:benefit_markets_locations_service_area) }
      let!(:rating_area)                    { FactoryGirl.create(:benefit_markets_locations_rating_area) }
      let!(:service_area)                   { FactoryGirl.create(:benefit_markets_locations_service_area) }
      let(:this_year)                       { TimeKeeper.date_of_record.year }

      let(:april_effective_date)            { Date.new(this_year,4,1) }
      let(:april_open_enrollment_begin_on)  { april_effective_date - 1.month }
      let(:april_open_enrollment_end_on)    { april_open_enrollment_begin_on + 9.days }

      let!(:april_sponsors) do
        create_list(:benefit_sponsors_benefit_sponsorship, 10, :with_organization_cca_profile,
                    :with_initial_benefit_application, initial_application_state: :active,
                                                       default_effective_period: (april_effective_date..(april_effective_date + 1.year - 1.day)),
                                                       site: site, aasm_state: :active)
      end

      let!(:april_renewal_sponsors) do
        create_list(:benefit_sponsors_benefit_sponsorship, 10, :with_organization_cca_profile,
                    :with_renewal_benefit_application, initial_application_state: :active,
                                                       renewal_application_state: :enrollment_open,
                                                       default_effective_period: (april_effective_date..(april_effective_date + 1.year - 1.day)), site: site,
                                                       aasm_state: :active)
      end

      context "scopes" do
        context "benefit application" do
          before do
          end

          context "enrolled" do
            xit "should return a valid datatable only including enrolled benefit applications" do

            end
          end
        end
        context "employer attestations" do
          let(:random_org) do
            BenefitSponsors::Organizations::Organization.all.detect do |org|
              org.employer_profile.present? && org.employer_profile.employer_attestation.present?
            end
          end
          let(:random_org_profile){ random_org.employer_profile }
          let(:non_attestation_org) do
            BenefitSponsors::Organizations::Organization.all.detect do |org|
              org.employer_profile.present? &&
                org.employer_profile.employer_attestation.present? &&
                org.benefit_sponsorships.present?
            end
          end
          let(:non_attestation_profile) { non_attestation_org.employer_profile }

          before do
            # Submitted is an employer attestation status
            random_org_profile.employer_attestation.update_attributes(aasm_state: "submitted")
            # Destroy to make sure it doens't appear
            non_attestation_profile.employer_attestation.destroy
            employer_attestation_attributes = {
              "custom_attributes" => nil,
              "employers" => "employer_attestations"
            }.with_indifferent_access
            @datatable = ::Effective::Datatables::BenefitSponsorsEmployerDatatable.new
            @datatable.attributes = employer_attestation_attributes
          end

          it "should return a valid datatable only including employer attestation benefit sponsorship" do
            random_org_profile_benefit_sponsorship_id = random_org_profile.benefit_sponsorships.last.id.to_s
            expect(@datatable.collection.where(_id: random_org_profile_benefit_sponsorship_id).first.present?).to eq(true)
            non_attestation_profile_benefit_sponsorship_id = non_attestation_profile.benefit_sponsorships.last.id.to_s
            expect(@datatable.collection.where(_id: non_attestation_profile_benefit_sponsorship_id).first.present?).to eq(true)
          end
        end
      end
    end
  end
end