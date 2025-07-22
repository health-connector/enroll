# frozen_string_literal: true

require "rails_helper"

require File.join(Rails.root, "app", "data_migrations", "products", "mark_premium_value_products_in_rating_areas")

describe Products::MarkPremiumValueProductsInRatingAreas, dbclean: :after_each do
  before :all do
    DatabaseCleaner.clean
  end

  let(:given_task_name) { "mark_premium_value_products_in_rating_areas" }

  let!(:site)            { FactoryBot.create(:benefit_sponsors_site, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, Settings.site.key) }
  let(:effective_date)   { TimeKeeper.date_of_record.beginning_of_year }
  let(:catalog)          { site.benefit_markets[0].benefit_market_catalogs[0] }
  let(:product)          { catalog.product_packages[0].products.first }
  let(:user)             { FactoryBot.create(:user) }

  let!(:rating_area) do
    r = product.premium_tables.first.rating_area
    r.update!(exchange_provided_code: "R-MA002")
    r
  end

  subject { Products::MarkPremiumValueProductsInRatingAreas.new(given_task_name, double(:current_scope => nil)) }

  let(:file_name) { File.expand_path("#{Rails.root}/spec/test_data/pvp_plans.csv") }

  before do
    headers = ["ActiveYear", "HiosId", "RatingAreaCode", "PvpEligibility", "UserEmail"]
    CSV.open(file_name, "w", force_quotes: true) do |csv|
      csv << headers
      csv << [product.active_year, product.hios_id, rating_area.exchange_provided_code[-1], true, user.email]
    end
  end

  after :all do
    file_name = File.expand_path("#{Rails.root}/spec/test_data/pvp_plans.csv")
    FileUtils.rm_f(file_name)
    DatabaseCleaner.clean
  end

  around do |example|
    ClimateControl.modify file_name: "spec/test_data/pvp_plans.csv" do
      example.run
    end
  end

  it "marks plans as pvp eligible" do
    expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 0
    subject.migrate
    expect(BenefitMarkets::Products::PremiumValueProduct.all.count).to eq 1
    pvp = BenefitMarkets::Products::PremiumValueProduct.all.first
    expect(pvp.eligibilities.count).to eq 1
    expect(pvp.eligibilities.first.eligible?).to be_truthy
  end
end