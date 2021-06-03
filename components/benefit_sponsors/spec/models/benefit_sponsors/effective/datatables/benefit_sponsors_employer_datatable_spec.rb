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
      let(:user)                            { double(:user, has_hbx_staff_role?: true, last_portal_visited: "www.google.com")}
      let(:valid_session)                   { {} }
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


      before do
        @datatable = ::Effective::Datatables::BenefitSponsorsEmployerDatatable.new
      end

      context "scopes" do
        context "employer attestations" do
          before do
            random_org = BenefitSponsors::Organizations::Organization.all.detect { |org| org.employer_profile.present? }
            profile = random_org.employer_profile
            profile.employer_attestation.update_attributes(aasm_state: "submitted")
            employer_attestation_attributes = {
              "custom_attributes" => nil,
              "employers"=>"employer_attestations"
            }.with_indifferent_access
            # This isn't hitting the attributes line I want it to in the datatable,
            # but this was working in the hbx_profiles_controller_spec. Why?
            allow_any_instance_of(
              Effective::Datatables::BenefitSponsorsEmployerDatatable
            ).to receive(:attributes).and_return(employer_attestation_attributes)
          end

          it "should return a valid datatable" do
            # expect(result?).to_somehow include_only(random_org)

          end
        end
      end
    end
  end
end