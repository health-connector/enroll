require "rails_helper"
require 'byebug'
require 'rake'

require File.join(Rails.root, "app", "data_migrations", "update_primary_phone_to_secondary_address")

describe UpdatePrimaryPhoneToSecondaryAddress, dbclean: :after_each do
  let(:given_task_name) {"update_primary_phone_to_secondary_address"}
  subject { UpdatePrimaryPhoneToSecondaryAddress.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end
  describe "Add Primary Family to the Person" do
      let(:address)  { Address.new(kind: "primary", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002", county: "County") }
      let(:phone)  { Phone.new(kind: "main", area_code: "202", number: "555-9999") }
      let(:office_location) { OfficeLocation.new(
          is_primary: true,
          address: address,
          phone: phone
        )
      }
      let(:address_1)  { Address.new(kind: "mailing", address_1: "235 E St", city: "Boston", state: "MA", zip: "10030", county: "County") }
      let(:phone_1)  { Phone.new(kind: "main", area_code: "125", number: "213-4567") }
      let(:office_location_1) { OfficeLocation.new(
          is_primary: false,
          address: address_1,
          phone: phone_1
        )
      }

      let(:organization) { Organization.create(
        legal_name: "Sail Adventures, Inc",
        dba: "Sail Away",
        fein: "001223833",
        office_locations: [office_location, office_location_1]
        )
      }
    before(:each) do
    end
    it 'should add primary office location phone number to secondary office location' do
      organization.office_locations.where(:is_primary => false).first.update_attributes(:phone => nil)
      subject.migrate
      organization.reload
      (expect(organization.office_locations.where(:is_primary => false).first.phone)).to eql (organization.office_locations.where(:is_primary => true).first.phone)
    end
    it 'should not add primary office location phone number to secondary office location' do
      subject.migrate
      organization.reload
      (expect(organization.office_locations.where(:is_primary => false).first.phone)).not_to eq (organization.office_locations.where(:is_primary => true).first.phone)
    end
  end
end