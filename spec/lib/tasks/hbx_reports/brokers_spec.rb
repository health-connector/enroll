# frozen_string_literal: true

require 'rails_helper'
require 'csv'
require 'rake'

RSpec.describe "reports:shop:brokers", type: :task do
  include Config::AcaHelper

  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require(
      "tasks/hbx_reports/brokers",
      [Rails.root.join("lib").to_s]
    )
    Rake::Task.define_task(:environment)
  end
  let(:task) { Rake::Task["reports:shop:brokers"] }

  let(:site) do
    create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca)
  end

  let(:employer_organization) do
    build(
      :benefit_sponsors_organizations_general_organization,
      :with_aca_shop_cca_employer_profile,
      site: site
    )
  end

  let(:employer_profile) { employer_organization.profiles.first }

  let!(:benefit_sponsorship) do
    create(
      :benefit_sponsors_benefit_sponsorship,
      profile: employer_profile,
      benefit_market: site.benefit_markets.first
    )
  end

  let!(:broker_agency_profile) do
    create(
      :benefit_sponsors_organizations_broker_agency_profile,
      market_kind: "shop",
      legal_name: "Legal Name1",
      assigned_site: site
    )
  end

  let!(:broker_role) do
    create(
      :broker_role,
      aasm_state: "active",
      benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id
    )
  end

  let(:person) { broker_role.person }

  let!(:user) do
    create(:user, person: person, last_sign_in_at: Time.zone.parse("2025-01-15 10:00:00"))
  end

  let(:file_name) do
    Rails.root.join(
      "public",
      "CCA_BROKERLIST_TEST.csv"
    ).to_s
  end

  let(:expected_headers) do
    %w[
      NPN
      Broker_Agency
      First_Name
      Last_Name
      Email
      Phone
      Market_kind
      Languages_spoken
      Evening/Weekend_hours
      Accept_new_clients
      Address_1
      Address_2
      City
      State
      Zip
      Application_Created_On
      Broker_Status
      Last_Status_Updated_On
      Approval_date
      Last_Login_Date
    ]
  end

  before do
    task.reenable

    allow_any_instance_of(Config::AcaHelper)
      .to receive(:fetch_file_format)
      .with("brokers_list", "BROKERSLIST")
      .and_return(file_name)
  end

  after do
    FileUtils.rm_f(file_name)
  end

  it "runs without errors" do
    expect { task.invoke }.not_to raise_error
  end

  it "generates the CSV file at the path returned by fetch_file_format" do
    task.invoke

    expect(File.exist?(file_name)).to be(true)
  end


  it "writes the expected headers in the correct order" do
    task.invoke

    csv = CSV.read(file_name, headers: true)
    expect(csv.headers).to eq(expected_headers)
  end

  it "includes a row for the broker with correctly mapped data" do
    task.invoke

    csv = CSV.read(file_name, headers: true)
    broker_row = csv.find { |row| row["NPN"] == broker_role.npn }

    expect(broker_row).not_to be_nil
    expect(broker_row["NPN"]).to eq(broker_role.npn)
    expect(broker_row["Languages_spoken"]).to eq(broker_agency_profile.languages_spoken.to_s)
    expect(broker_row["Broker_Agency"]).to eq(broker_agency_profile.legal_name)
    expect(broker_row["First_Name"]).to eq(person.first_name)
    expect(broker_row["Last_Name"]).to eq(person.last_name)
    expect(broker_row["Email"]).to eq(broker_role.email_address)
    expect(broker_row["Phone"]).to eq(broker_role.phone.to_s)
    expect(broker_row["Market_kind"]).to eq(broker_agency_profile.market_kind.to_s)
    expect(broker_row["Last_Login_Date"]).to eq(user.last_sign_in_at.strftime("%Y-%m-%d"))
    expect(broker_row["Address_1"]).to eq(broker_agency_profile.primary_office_location.address.address_1)
    expect(broker_row["Address_2"]).to eq(broker_agency_profile.primary_office_location.address.address_2)
    expect(broker_row["City"]).to eq(broker_agency_profile.primary_office_location.address.city)
    expect(broker_row["State"]).to eq(broker_agency_profile.primary_office_location.address.state)
    expect(broker_row["Zip"]).to eq(broker_agency_profile.primary_office_location.address.zip)
    expect(broker_row["Application_Created_On"]).to eq(broker_role.created_at.try(:strftime,'%Y-%m-%d'))
    expect(broker_row["Broker_Status"]).to eq(broker_role.aasm_state)
    expect(broker_row["Last_Status_Updated_On"]).to eq(broker_role.updated_at.try(:strftime,'%Y-%m-%d'))
  end
end