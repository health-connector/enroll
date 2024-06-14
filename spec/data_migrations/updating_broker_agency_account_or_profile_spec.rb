# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "updating_broker_agency_account_or_profile")

describe UpdatingBrokerAgencyAccountOrProfile, dbclean: :after_each do

  let!(:given_task_name) { "delinking_broker" }
  let!(:person) { FactoryBot.create(:person,:with_broker_role)}
  let!(:organization1) {FactoryBot.create(:organization)}
  let!(:organization) {FactoryBot.create(:organization)}
  let!(:fein){"929129912"}
  let!(:employer_profile) { FactoryBot.create(:employer_profile, organization: organization)}
  let!(:broker_agency_profile) {FactoryBot.create(:broker_agency_profile, organization: organization1)}
  let!(:office_locations_contact) {FactoryBot.build(:phone, kind: "work")}
  let!(:office_locations) {FactoryBot.build(:address, kind: "branch")}
  let!(:broker_agency_account) {FactoryBot.create(:broker_agency_account, broker_agency_profile: broker_agency_profile, writing_agent_id: person.broker_role.id, is_active: true, employer_profile: employer_profile)}
  let!(:new_person) { FactoryBot.create(:person)}
  let!(:family) {FactoryBot.create(:family,:with_primary_family_member, person: new_person, broker_agency_accounts: [broker_agency_account])}

  subject { UpdatingBrokerAgencyAccountOrProfile.new(given_task_name, double(:current_scope => nil)) }

  context "create_org_and_broker_agency_profile" do
    before(:each) do
      employer_profile.broker_agency_accounts << broker_agency_account
    end

    it "Should update the person broker_role id with with new broker_agency" do
      ClimateControl.modify person_hbx_id: person.hbx_id,
                            legal_name: organization.legal_name,
                            fein: fein,
                            defualt_general_agency_id: broker_agency_profile.default_general_agency_profile_id,
                            npn: person.broker_role.npn,
                            address_1: office_locations.address_1,
                            address_2: office_locations.address_2,
                            city: office_locations.city,
                            state: office_locations.state,
                            zip: office_locations.zip,
                            area_code: office_locations_contact.area_code,
                            number: office_locations_contact.number,
                            market_kind: broker_agency_profile.market_kind,
                            action: 'create_org_and_broker_agency_profile' do
        subject.migrate
        person.reload
        expect(person.broker_role.broker_agency_profile.organization.fein).to eq fein
      end
    end
  end

  context "update_broker_role" do
    before(:each) do
      employer_profile.broker_agency_accounts << broker_agency_account
    end

    it "Should update the person broker_role id with with new broker_agency" do
      ClimateControl.modify person_hbx_id: person.hbx_id,
                            legal_name: organization.legal_name,
                            fein: fein,
                            defualt_general_agency_id: broker_agency_profile.default_general_agency_profile_id,
                            npn: person.broker_role.npn,
                            address_1: office_locations.address_1,
                            address_2: office_locations.address_2,
                            city: office_locations.city,
                            state: office_locations.state,
                            zip: office_locations.zip,
                            area_code: office_locations_contact.area_code,
                            number: office_locations_contact.number,
                            market_kind: 'both',
                            broker_agency_profile_id: broker_agency_profile.id,
                            action: 'update_broker_role' do
        subject.migrate
        person.reload
        expect(person.broker_role.market_kind).to eq 'both'
      end
    end
  end

  context "update_family_broker_agency_account_with_writing_agent" do
    # Can't be fixed as the broker agency accounts association with family updated with new model.
    # it "Should update the writing agent of broker agency account" do
    #   new_person.primary_family.broker_agency_accounts.first.update_attributes(writing_agent_id: '')
    #   expect(new_person.primary_family.broker_agency_accounts.first.writing_agent).to eq nil
    #   subject.migrate
    #   new_person.primary_family.reload
    #   expect(new_person.primary_family.broker_agency_accounts.first.writing_agent).to eq broker_agency_profile.primary_broker_role
    # end
  end
end
