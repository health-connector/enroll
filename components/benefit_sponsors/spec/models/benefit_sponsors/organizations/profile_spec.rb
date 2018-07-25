require 'rails_helper'

module BenefitSponsors
  RSpec.describe Organizations::Profile, type: :model, :dbclean => :after_each do

    let(:hbx_id) {"56789"}
    let(:legal_name) {"Tyrell Corporation"}
    let(:dba) {"Offworld Enterprises"}
    let(:fein) {"100001001"}
    let(:entity_kind) {:c_corporation}
    let(:contact_method) {:paper_and_electronic}

    let!(:site) {BenefitSponsors::Site.new(site_key: :dc)}
    let(:organization) {BenefitSponsors::Organizations::GeneralOrganization.new(
        site: site,
        hbx_id: hbx_id,
        legal_name: legal_name,
        dba: dba,
        entity_kind: entity_kind,
        fein: fein,
    )}

    let(:address) {BenefitSponsors::Locations::Address.new(kind: "primary", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002", county: "County")}
    let(:phone) {BenefitSponsors::Locations::Phone.new(kind: "main", area_code: "202", number: "555-9999")}
    let(:office_location) {BenefitSponsors::Locations::OfficeLocation.new(is_primary: true, address: address, phone: phone)}
    let(:office_locations) {[office_location]}


    let(:params) do
      {
          organization: organization,
          office_locations: office_locations,
          contact_method: contact_method,
      }
    end

    describe "model matchers" do
      context "has to check for fields types" do
        it {
          is_expected.to have_field(:is_benefit_sponsorship_eligible).of_type(Mongoid::Boolean).with_default_value_of(false)
          is_expected.to have_field(:contact_method).of_type(Symbol).with_default_value_of(:paper_and_electronic)
        }
      end

      context "has to check for relationships" do
        it {
          is_expected.to embed_many(:office_locations)
          is_expected.to embed_one(:inbox)
          is_expected.to have_many(:documents)
          is_expected.to accept_nested_attributes_for(:office_locations)
          is_expected.to be_embedded_in(:organization)
        }
      end

      context "has to check for validators" do
        it {
          is_expected.to validate_presence_of(:office_locations)
        }
      end
    end

    context "A new model instance" do
      context "with no organization" do
        subject {described_class.new(params.except(:organization))}

        it "should not be valid" do
          subject.validate
          expect {subject.save!}.to raise_error(Mongoid::Errors::NoParent)
        end
      end

      # Contact method set by default in the model
      context "with no contact_method" do
        subject {described_class.new(params.except(:contact_method))}

        it "should not be valid" do
          subject.validate
          expect(subject).to be_valid
        end

        context "or contact method is invalid" do
          let(:invalid_contact_method) {:snapchat}

          before {subject.contact_method = invalid_contact_method}

          it "should not be valid" do
            subject.validate
            expect(subject).to_not be_valid
          end
        end
      end

      context "with no office_locations" do
        subject {described_class.new(params.except(:office_locations))}

        it "should not be valid" do
          subject.validate
          expect(subject).to_not be_valid
        end
      end

      context "without a primary office location" do
        let(:invalid_address) {BenefitSponsors::Locations::Address.new(kind: "work", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002", county: "County")}
        let(:invalid_office_location) {BenefitSponsors::Locations::OfficeLocation.new(is_primary: false, address: invalid_address, phone: phone)}

        subject {described_class.new(office_locations: [invalid_office_location])}

        it "should not be valid"
      end

      context "with all required arguments", dbclean: :after_each do
        subject {described_class.new(params)}

        it "is_benefit_sponsorship_eligible attribute should default to false" do
          expect(subject.is_benefit_sponsorship_eligible).to eq false
        end

        context "and all arguments are valid" do
          before {
            site.byline = 'test'
            site.long_name = 'test'
            site.short_name = 'test'
            site.domain_name = 'test'
            site.owner_organization = organization
            site.site_organizations << organization
            organization.profiles << subject
          }

          it "should be valid" do
            subject.validate
            expect(subject).to be_valid
          end

          it "should be able to access parent values for delegated attributes" do
            expect(subject.hbx_id).to eq hbx_id
            expect(subject.legal_name).to eq legal_name
            expect(subject.dba).to eq dba
            expect(subject.fein).to eq fein
          end

          it "should save and be findable" do
            expect(site.save!).to eq true
            expect(organization.save!).to eq true

            expect(subject.save!).to eq true
            expect(BenefitSponsors::Organizations::Profile.find(subject.id)).to eq subject
          end

        end
      end

      context "local delegated attributes are updated" do
        subject {described_class.new(params)}

        let(:changed_legal_name) {"Wallace Corporation"}
        let(:changed_dba) {"Offworld Adventures"}
        let(:changed_fein) {"200002002"}

        before do
          subject.legal_name = changed_legal_name
          subject.dba = changed_dba
          subject.fein = changed_fein
        end

        it "should update attribute values on the parent model" do
          expect(subject.organization.legal_name).to eq changed_legal_name
          expect(subject.organization.dba).to eq changed_dba
          expect(subject.organization.fein).to eq changed_fein
        end
      end
    end

    describe "Factory validation" do
      let(:benefit_sponsor_organization) {FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile)}
      let(:office_location) {FactoryGirl.build(:benefit_sponsors_locations_office_location)}
      let(:factory_builder) {FactoryGirl.build(:benefit_sponsors_organizations_profile, organization: benefit_sponsor_organization, office_locations: [office_location])}
      let(:factory_creater) {FactoryGirl.create(:benefit_sponsors_organizations_profile, organization: benefit_sponsor_organization, office_locations: [office_location])}
      it "should be able to create a valid factory" do
        expect(factory_creater.valid?).to be_truthy
      end

      it "should be able to build a valid factory" do
        expect(factory_builder.valid?).to be_truthy
      end
    end


    context "Adding an initial BenefitSponsorship" do
      let(:benefit_sponsor_organization) {FactoryGirl.build(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile)}
      let(:office_location) {FactoryGirl.build(:benefit_sponsors_locations_office_location)}
      let(:factory_creater) {FactoryGirl.build(:benefit_sponsors_organizations_profile, is_benefit_sponsorship_eligible: true, organization: benefit_sponsor_organization, office_locations: [office_location])}

      context "and an initial BenefitSponsorship is added" do

        it "should be successful" do
          expect(factory_creater.benefit_sponsorships.empty?).to be_truthy
          factory_creater.add_benefit_sponsorship
          expect(factory_creater.benefit_sponsorships.empty?).to be_falsy
        end

        context "and it is saved" do
          it "should be valid" do
            factory_creater.add_benefit_sponsorship
            expect(factory_creater.benefit_sponsorships.first.valid?).to be_truthy
          end
        end

      end

    end

    context "Adding a second or greater BenefitSponsorship" do

      context "and the prior BenefitSponsorship was canceled without effectuating enrollment" do

        context "and the benefit_application effective date is one date after the cancelation date" do
          it "should be valid"
        end

        context "and the benefit_application effective date is later than one day after the cancelation date" do
          it "should be valid"
        end

        context "and the benefit_application effective date is earlier than the most recent benefit_application cancelation" do
          it "should be valid"
        end
      end

      context "and the prior BenefitSponsorship was terminated after effectuating enrollment" do

        context "and the benefit_application effective date is one date after the termination date" do
        end

        context "and the benefit_application effective date is later than one day after the termination date" do
        end

        context "and the benefit_application effective date is earlier than the most recent benefit_application termination" do
          it "should be invalid"
        end
      end


      it "should become the new active benefit_sponsorship"

      it "the former benefit_sponsorship end date should be set and state transitioned"

      it "benefit with sponsored benefit has date gap sponsored_benefits then we need a new benefit_sponsorship"

      context "and BenefitSponsorship is canceled " do
      end
    end

    context "Sponsor moves primary office" do
      let(:benefit_sponsor_organization) {FactoryGirl.build(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile)}
      let(:office_location) {FactoryGirl.build(:benefit_sponsors_locations_office_location)}
      let(:factory_creater) {FactoryGirl.build(:benefit_sponsors_organizations_profile, is_benefit_sponsorship_eligible: true, organization: benefit_sponsor_organization, office_locations: [office_location])}

      it "notifies benefit_sponsorships with :primary_office_location_change event" do
        benefit_sponsorship = factory_creater.add_benefit_sponsorship
        allow(benefit_sponsorship).to receive(:profile_event_subscriber).with(:primary_office_location_change).and_return true
        factory_creater.primary_office_location.address.address_1 = "SOME OTHER STREET"
        expect(benefit_sponsorship).to receive(:profile_event_subscriber).with(:primary_office_location_change)
        factory_creater.save!
      end
    end
  end
end
