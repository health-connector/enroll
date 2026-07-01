# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'rubyXL'
require 'rubyXL/convenience_methods'

describe 'reports generation after plan loading', :dbclean => :after_each do

  let(:current_date) { Date.today.strftime("%Y_%m_%d") }
  let(:plan_year_period) { Time.utc(2019, 1, 1)..Time.utc(2019, 12, 31) }

  # Creates an issuer profile (carrier) and, by default, a product for every hios id.
  # Pass product_hios_ids to give the carrier hios ids that have no products.
  def create_carrier(abbrev:, hios_ids:, product_hios_ids: hios_ids)
    profile = FactoryBot.create(:benefit_sponsors_organizations_exempt_organization, :with_issuer_profile).issuer_profile
    profile.update(abbrev: abbrev, issuer_hios_ids: hios_ids)
    product_hios_ids.each { |hios_prefix| create_product(profile, hios_prefix) }
    profile
  end

  def create_product(profile, hios_prefix)
    FactoryBot.create(
      :benefit_markets_products_health_products_health_product,
      issuer_profile_id: profile.id,
      application_period: plan_year_period,
      benefit_market_kind: :aca_shop,
      kind: :health,
      product_package_kinds: [:single_issuer],
      hios_id: "#{hios_prefix}MA0100001-01"
    )
  end

  def generate_reports
    ClimateControl.modify active_date: "2019-12-01" do
      Rake::Task["cca_plan_validation:reports"].reenable
      Rake::Task["cca_plan_validation:reports"].invoke
    end
  end

  def report_path(slug)
    "#{Rails.root}/CCA_PlanLoadValidation_Report_#{slug}_#{current_date}.xlsx"
  end

  # CarrierId (hios id) values found in the data rows of a report's first sheet.
  def carrier_ids_in(path)
    RubyXL::Parser.parse(path)[0].sheet_data[1..].map { |row| row&.cells&.at(1)&.value }.compact.uniq
  end

  before do
    load File.expand_path("#{Rails.root}/lib/tasks/cca_plan_validation_report.rake", __FILE__)
    Rake::Task.define_task(:environment)
    allow(Date).to receive(:today).and_return Date.new(2001, 2, 3)
  end

  after do
    FileUtils.rm_f(Dir.glob(report_path("*")))
  end

  context 'with a single carrier' do
    let(:file_name) { report_path("TEST_88888") }

    before do
      create_carrier(abbrev: "TEST", hios_ids: ["88888"])
      generate_reports
    end

    it 'generates a workbook for the carrier' do
      expect(File).to exist(file_name)
    end

    it 'writes the expected headers on every sheet' do
      sheet_headers = [
        ["PlanYearId", "CarrierId", "CarrierName", "PlanTypeCode", "Tier", "Count"],
        ["PlanYearId", "CarrierId", "CarrierName", "RatingArea", "Age(Range)", "IndividualRate", "EffectiveDate", "ExpirationDate"],
        ["PlanYearId", "CarrierId", "CarrierName", "ServiceAreaCode", "PlanCount", "County_Count", "Zip_Count"],
        ["PlanYearId", "CarrierId", "CarrierName", "GroupSizeSum", "GroupSizeFactorSum"],
        ["PlanYearId", "CarrierId", "CarrierName", "GroupSizeSum", "ParticipationRateSum"],
        ["PlanYearId", "CarrierId", "CarrierName", "SIC_Count", "SICRateSum"],
        ["CarrierId", "CarrierName", "ProductModel", "PlanCount"],
        ["CarrierId", "CarrierName", "HIOS_ID", "Renewal_HIOS_ID"],
        ["PlanYearId", "CarrierId", "CarrierName", "HIOS_Plan_ID", "SG_ID"]
      ]

      workbook = RubyXL::Parser.parse(file_name)
      aggregate_failures do
        sheet_headers.each_with_index do |headers, index|
          expect(workbook[index].sheet_data[0].cells.map(&:value)).to eq(headers)
        end
      end
    end
  end

  context 'when a carrier has a hios id with no products' do
    before do
      create_carrier(abbrev: "FALLON", hios_ids: ["88888", "52710"], product_hios_ids: ["88888"])
      generate_reports
    end

    it 'omits the productless hios id from the filename' do
      expect(File).to exist(report_path("FALLON_88888"))
      expect(File).not_to exist(report_path("FALLON_88888_52710"))
    end
  end

  context 'with multiple carriers' do
    before do
      create_carrier(abbrev: "TEST", hios_ids: ["88888"])
      create_carrier(abbrev: "BTWO", hios_ids: ["99999"])
      generate_reports
    end

    it 'generates one file per carrier' do
      expect(File).to exist(report_path("TEST_88888"))
      expect(File).to exist(report_path("BTWO_99999"))
    end

    it 'scopes each workbook to only that carrier data' do
      expect(carrier_ids_in(report_path("TEST_88888"))).to eq([88888])
      expect(carrier_ids_in(report_path("BTWO_99999"))).to eq([99999])
    end
  end
end
