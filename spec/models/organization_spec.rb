# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, dbclean: :after_each do
  it { should validate_presence_of :legal_name }
  it { should validate_presence_of :fein }
  it { should validate_presence_of :office_locations }

  let(:legal_name) {"Acme Brokers, Inc"}
  let(:fein) {"065872626"}
  let(:bad_fein) {"123123"}
  let(:office_locations) {FactoryBot.build(:office_locations)}
  let(:invoice) { FactoryBot.create(:document) }
  let(:org) { FactoryBot.create(:organization) }
  let(:file_path){ "test/hbxid_01012001_invoice_R.pdf"}
  let(:valid_file_names){ ["hbxid_01012001_invoice_R.pdf","hbxid_04012014_invoice_R.pdf","hbxid_10102001_invoice_R.pdf"] }

  let(:fein_error_message) {"#{bad_fein} is not a valid FEIN"}

  let(:valid_office_location_attributes) do
    {
      address: FactoryBot.build(:address, kind: "work"),
      phone: FactoryBot.build(:phone, kind: "work")
    }
  end

  let(:valid_params) do
    {
      legal_name: legal_name,
      fein: fein,
      office_locations: [valid_office_location_attributes]
    }
  end

  describe ".create" do
    context "with valid arguments" do
      let(:params) {valid_params}
      let(:organization) {Organization.create(**params)}
      before do
        organization.valid?
      end

      it "should have assigned an hbx_id" do
        expect(organization.hbx_id).not_to eq nil
      end

      context "and a second organization is created with the same fein" do
        let(:organization2) {Organization.create(**params)}
        before do
          organization2.valid?
        end

        context "the second organization" do
          it "should not be valid" do
            expect(organization2.valid?).to be false
          end

          it "should have an error on fein" do
            expect(organization2.errors[:fein].any?).to be true
          end

          it "should not have the same id as the first organization" do
            expect(organization2.id).not_to eq organization.id
          end
        end
      end
    end
  end


  describe ".new" do

    context "with no arguments" do
      let(:params) {{}}

      it "should not save" do
        expect(Organization.new(**params).save).to be_falsey
      end
    end

    context "with all valid arguments" do
      let(:params) {valid_params}

      it "should save" do
        expect(Organization.new(**params).save).to be_truthy
      end
    end

    context "with no legal_name" do
      let(:params) {valid_params.except(:legal_name)}

      it "should fail validation" do
        expect(Organization.create(**params).errors[:legal_name].any?).to be_truthy
      end
    end

    context "with no fein" do
      let(:params) {valid_params.except(:fein)}

      it "should fail validation" do
        expect(Organization.create(**params).errors[:fein].any?).to be_truthy
      end
    end

    context "with no office_locations" do
      let(:params) {valid_params.except(:office_locations)}

      it "should fail validation" do
        expect(Organization.create(**params).errors[:office_locations].any?).to be_truthy
      end
    end

    context "with invalid fein" do
      let(:params) {valid_params.deep_merge({fein: bad_fein})}

      it "should fail validation" do
        expect(Organization.create(**params).errors[:fein]).to eq [fein_error_message]
      end
    end
  end

  describe "class method", dbclean: :after_each do
    let(:organization1) {FactoryBot.create(:organization, legal_name: "Acme Inc")}
    let!(:carrier_profile_1) {FactoryBot.create(:carrier_profile, with_service_areas: 0, organization: organization1, issuer_hios_ids: ['11111'])}
    let(:organization2) {FactoryBot.create(:organization, legal_name: "Turner Inc")}
    let!(:carrier_profile_2) {FactoryBot.create(:carrier_profile, with_service_areas: 0, organization: organization2, issuer_hios_ids: ['22222'])}
    let(:single_choice_organization) {FactoryBot.create(:organization, legal_name: "Restricted Options")}
    let!(:sole_source_participater) { create(:carrier_profile, with_service_areas: 0, organization: single_choice_organization, offers_sole_source: true, issuer_hios_ids: ['11111']) }

    let!(:carrier_one_service_area) { create(:carrier_service_area, service_area_zipcode: '10001', issuer_hios_id: carrier_profile_1.issuer_hios_ids.first) }
    let(:address) { double(zip: '10001', county: 'County', state: Settings.aca.state_abbreviation) }
    let(:office_location) { double(address: address)}
    let(:carrier_plan) { instance_double(Plan, active_year: '2017', is_sole_source: true, is_vertical: false, is_horizontal: false) }

    before :each do
      Rails.cache.clear
    end

    context "carrier_names" do
      before :each do
        allow(Plan).to receive(:valid_shop_health_plans).and_return([carrier_plan])
      end

      context "base case" do
        it "valid_carrier_names" do
          carrier_names = {}
          carrier_names[carrier_profile_1.id.to_s] = carrier_profile_1.legal_name
          carrier_names[carrier_profile_2.id.to_s] = carrier_profile_2.legal_name
          carrier_names[sole_source_participater.id.to_s] = sole_source_participater.legal_name
          expect(Organization.valid_carrier_names).to match_array carrier_names
        end

        it "valid_carrier_names_for_options" do
          carriers = [[carrier_profile_1.legal_name, carrier_profile_1.id.to_s], [carrier_profile_2.legal_name, carrier_profile_2.id.to_s],[sole_source_participater.legal_name, sole_source_participater.id.to_s]]
          expect(Organization.valid_carrier_names_for_options).to match_array carriers
        end

        it "valid_carrier_names_for_options passes arguments and filters to sole source only" do
          carriers = [[sole_source_participater.legal_name, sole_source_participater.id.to_s]]
          expect(Organization.valid_carrier_names_for_options(sole_source_only: true)).to match_array carriers
        end

        it "can filter out by service area" do
          carrier_names = {}
          carrier_names[carrier_profile_1.id.to_s] = carrier_profile_1.legal_name
          carrier_names[sole_source_participater.id.to_s] = sole_source_participater.legal_name

          expect(Organization.valid_carrier_names(primary_office_location: office_location)).to match_array carrier_names
        end
      end

      context "when limiting carriers to service area and coverage selection level and active year" do
        before do
          date = Date.new(2017,1,1)
          allow(CarrierServiceArea).to receive(:valid_for_carrier_on).and_return([])
          allow(CarrierServiceArea).to receive(:valid_for_carrier_on).with(address: address, carrier_profile: carrier_profile_1, year: date.year, quote_effective_date: date).and_return([carrier_one_service_area])
          allow(CarrierServiceArea).to receive(:valid_for_carrier_on).with(address: address, carrier_profile: carrier_profile_1, year: date.year + 1, quote_effective_date: date + 1.year).and_return([carrier_one_service_area])
          allow(CarrierServiceArea).to receive(:valid_for_carrier_on).with(address: address, carrier_profile: sole_source_participater, year: date.year + 1, quote_effective_date: date + 1.year).and_return([carrier_one_service_area])
          allow(Plan).to receive(:valid_shop_health_plans).with("carrier", carrier_profile_2.id, 2017).and_return([])
          allow(Plan).to receive(:valid_shop_health_plans).with("carrier", sole_source_participater.id, 2017).and_return([])
          allow(Plan).to receive(:valid_shop_health_plans).with("carrier", sole_source_participater.id, 2018).and_return([carrier_plan])
          allow(Plan).to receive(:valid_shop_health_plans).with("carrier", carrier_profile_1.id, 2017).and_return([carrier_plan])
          allow(Plan).to receive(:valid_shop_health_plans).with("carrier", carrier_profile_1.id, 2018).and_return([carrier_plan])
        end

        it "returns no carriers if there are no matches" do
          expect(Organization.valid_carrier_names(primary_office_location: office_location, active_year: 2017, selected_carrier_level: 'metal_level')).to match_array []
          expect(Organization.valid_carrier_names(primary_office_location: office_location, active_year: 2017, selected_carrier_level: 'single_plan')).to match_array []
        end
      end
    end

    context "binder_paid" do
      let(:address)  { Address.new(kind: "primary", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002", county: "County") }
      let(:phone)  { Phone.new(kind: "main", area_code: "202", number: "555-9999") }
      let(:office_location) do
        OfficeLocation.new(
          is_primary: true,
          address: address,
          phone: phone
        )
      end
      let(:organization) do
        Organization.create(
          legal_name: "Sail Adventures, Inc",
          dba: "Sail Away",
          fein: "001223833",
          office_locations: [office_location]
        )
      end
      let(:valid_params) do
        {
          organization: organization,
          entity_kind: "partnership",
          sic_code: '1111'
        }
      end
      let(:renewing_plan_year)    { FactoryBot.build(:plan_year, start_on: TimeKeeper.date_of_record.next_month.beginning_of_month - 1.year, end_on: TimeKeeper.date_of_record.end_of_month, aasm_state: 'renewing_enrolling') }
      let(:new_plan_year)    { FactoryBot.build(:plan_year, start_on: TimeKeeper.date_of_record.next_month.beginning_of_month, end_on: (TimeKeeper.date_of_record + 1.year).end_of_month, aasm_state: 'enrolling') }
      let(:new_employer)     { EmployerProfile.new(**valid_params, plan_years: [new_plan_year]) }
      let(:renewing_employer)     { EmployerProfile.new(**valid_params, plan_years: [renewing_plan_year]) }

      before do
        renewing_employer.save!
        new_employer.save!
      end

      it "should return correct number of records" do
        expect(Organization.retrieve_employers_eligible_for_binder_paid.size).to eq 1
      end
    end
  end

  context "primary_office_location" do
    let(:organization) {FactoryBot.build(:organization)}
    let(:office_location) {FactoryBot.build(:office_location, :primary)}
    let(:office_location2) {FactoryBot.build(:office_location, :primary)}

    it 'should save fail with more than one primary office_location' do
      organization.office_locations = [office_location, office_location2]
      expect(organization.save).to eq false
    end

    it "should save success with one primary office_location" do
      organization.office_locations = [office_location]
      expect(organization.save).to eq true
    end
  end

  context "primary_mailing_address" do
    let!(:organization) {FactoryBot.build(:organization)}
    let!(:office_location) {FactoryBot.build(:office_location, :with_mailing_address)}

    before :each do
      organization.office_locations = [office_location]
      organization.primary_mailing_address
    end

    it 'should return a valid primary_mailing_address for organization' do
      expect(organization.primary_mailing_address).to eq office_location.address
      expect(organization.primary_mailing_address.kind).to eq "mailing"
    end

    it "should not return an invalid address" do
      expect(organization.primary_mailing_address.kind).not_to eq "branch"
    end
  end

  context "Invoice Upload" do
    let!(:organization) {FactoryBot.create(:organization, :hbx_id => 'hbxid')}
    let!(:employer_profile) { FactoryBot.create(:employer_profile, organization: organization) }
    before do
      allow(Aws::S3Storage).to receive(:save).and_return("urn:openhbx:terms:v1:file_storage:s3:bucket:invoices:asdds123123")
      allow(Organization).to receive(:by_invoice_filename).and_return(organization)
    end

    context "with valid arguments" do
      before do
        Organization.upload_invoice(file_path,valid_file_names.first)
      end
      it "should upload invoice to the organization" do
        expect(organization.invoices.size).to eq 1
      end
    end
    context "with duplicate files" do

      it "should upload invoice to the organization only once" do
        Organization.upload_invoice(file_path,valid_file_names.first)
        Organization.upload_invoice(file_path,valid_file_names.first)
        expect(organization.invoices.size).to eq 1
      end
    end

    context "without date in file name" do
      before do
        Organization.upload_invoice("test/hbxid_invoice_R.pdf",'dummyfile.pdf')
      end
      it "should Not Upload invoice" do
        expect(organization.invoices.size).to eq 0
      end
    end
  end

  context "invoice_date" do
    context "with valid date in the file name" do
      it "should parse the date" do
        valid_file_names.each do |file_name|
          expect(Organization.invoice_date(file_name)).to be_an_instance_of(Date)
        end
      end
    end
  end

  context "has_premium_tables" do
    let(:plan) { FactoryBot.create(:plan, :with_premium_tables)}

    context "base case" do
      it "has_premium_tables for current year plan" do
        plan.reload
        expect(Organization.has_premium_tables?(plan.carrier_profile.organization)).to be_truthy
      end
    end
  end

  describe "notify_legal_name_or_fein_change" do

    context "notify update" do
      let(:employer_profile) { FactoryBot.build(:employer_profile) }
      let(:organization) {FactoryBot.create(:organization, employer_profile: employer_profile)}
      let(:changed_fields) { ["legal_name", "version", "updated_at"] }
      let(:changed_fields1) { ["fein", "version", "updated_at"] }

      it "notify legal name updated" do
        organization.instance_variable_set(:@changed_fields, changed_fields)
        expect(organization).to receive(:notify).exactly(1).times
        organization.notify_legal_name_or_fein_change
      end

      it "notify fein updated" do
        organization.instance_variable_set(:@changed_fields, changed_fields1)
        expect(organization).to receive(:notify).exactly(1).times
        organization.notify_legal_name_or_fein_change
      end
    end
  end

  describe "legal_name_or_fein_change_attributes" do

    context "changed_attributes" do
      let(:employer_profile) { FactoryBot.build(:employer_profile) }
      let(:organization) {FactoryBot.create(:organization, employer_profile: employer_profile)}

      it "legal_name changed_attributes " do
        organization.legal_name = "test1"
        organization.save!
        expect(organization.instance_variable_get(:@changed_fields)).to eq ["legal_name", "updated_at"]
      end

      it "fein changed_attributes" do
        organization.fein = "000000001"
        organization.save
        expect(organization.instance_variable_get(:@changed_fields)).to eq ["fein", "updated_at"]
      end
    end
  end

  describe "check_legal_name_or_fein_changed?" do

    context "legal and fein change" do
      let(:employer_profile) { FactoryBot.build(:employer_profile) }
      let(:organization) {FactoryBot.create(:organization, employer_profile: employer_profile)}

      it "return true for legal name update" do
        expect(organization.legal_name_changed?).to eq false #before update
        organization.legal_name = "test1"
        expect(organization.legal_name_changed?).to eq true #after update
        organization.save!
      end

      it "return true for fein update" do
        expect(organization.fein_changed?).to eq false
        organization.fein = "000000001"
        expect(organization.fein_changed?).to eq true
        organization.save
      end
    end
  end

  describe "check employer_attestations scopes" do
    context "employer attestation documents scope" do
      it "should return exact scope match records" do
        ["submitted","approved","pending","denied"].each do |state|
          FactoryBot.create(:organization,
                            employer_profile: FactoryBot.build(:employer_profile,
                                                               employer_attestation:  FactoryBot.build(:employer_attestation,{aasm_state: state})))
        end
        expect(Organization.employer_attestations_submitted[0].employer_profile.employer_attestation.aasm_state).to eq "submitted"
        expect(Organization.employer_attestations_pending[0].employer_profile.employer_attestation.aasm_state).to eq "pending"
        expect(Organization.employer_attestations_approved[0].employer_profile.employer_attestation.aasm_state).to eq "approved"
        expect(Organization.employer_attestations_denied[0].employer_profile.employer_attestation.aasm_state).to eq "denied"
      end
    end
  end

end
