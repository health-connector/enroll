# frozen_string_literal: true

# These rake tasks should be run to generate reports after plans loading.
# To run all reports please use this rake command: RAILS_ENV=production bundle exec rake plan_validation:reports['2020']

namespace :plan_validation do

  desc "reports generation after plan loading"
  task :reports, [:plan_year] => :environment do |_task, args|
    puts "Reports generation started" unless Rails.env.test?
    puts "Reports generation started for Report1" unless Rails.env.test?
    Rake::Task['plan_validation:report1'].invoke(args[:plan_year])
    puts "Reports generation started for Report2" unless Rails.env.test?
    Rake::Task['plan_validation:report2'].invoke(args[:plan_year])
  end

  #To run first report: RAILS_ENV=production bundle exec rake plan_validation:report1['2020']
  desc "Details about Plan Count by Carrier, Coverage and Tier"
  task :report1, [:plan_year] => :environment do |_task, args|
    CSV.open("#{Rails.root}/plan_validation_report1_#{args[:plan_year]}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName PlanTypeCode Tier Count]
      products = ::BenefitMarkets::Products::Product.by_year(args[:plan_year])
      products.all.each do |product|
        plan_year_id = product.active_year
        carrier_id = product.hios_id[0..4]
        carrier_name = product.issuer_profile.abbrev
        plan_type_code = product.kind == :health ? "QHP" : "QDP"
        tier = product.metal_level_kind
        product_count = ::BenefitMarkets::Products::Product.by_year(plan_year_id).where(hios_id: /#{carrier_id}/i, metal_level_kind: tier).count
        csv << [plan_year_id, carrier_id, carrier_name, plan_type_code, tier, product_count]
      end
      puts "Successfully generated Plan validation Report1"
    end
  end

  #To run second report: RAILS_ENV=production bundle exec rake plan_validation:report2['2020']
  desc "Rating Area and Age Based Plan Rate Sum"
  task :report2, [:plan_year] => :environment do |_task, args|
    plan_year_id = args[:plan_year]
    CSV.open("#{Rails.root}/plan_validation_report2_#{plan_year_id}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName RatingArea Age Sum]
      issuer_hios_ids = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten.flat_map(&:issuer_hios_ids).map(&:to_i)

      rating_area_ids = ::BenefitMarkets::Locations::RatingArea.where(active_year: plan_year_id).inject({}) do |data, ra|
        data[ra.id.to_s] = ra.exchange_provided_code
        data
      end

      issuer_hios_ids.each do |issuer_hios_id|
        products = ::BenefitMarkets::Products::Product.by_year(plan_year_id).where(hios_id: /#{issuer_hios_id}/)
        rating_area_ids.each do |rating_area_key, rating_area_value|
          premium_tables = products.map(&:premium_tables).flatten.select{|a| a.rating_area_id.to_s == rating_area_key}
          (0..120).each do |value|
            age = case value
                  when 0..14
                    14
                  when 64..120
                    64
                  else
                    value
                  end
            age_cost = premium_tables.map(&:premium_tuples).flatten.select{|a| a.age == age}.map(&:cost).sum
            carrier_name = products.first.issuer_profile.legal_name
            ra_val = rating_area_value.gsub("R-MA00", "Rating Area ")
            csv << [plan_year_id, issuer_hios_id, carrier_name, ra_val, value, age_cost.round(2)]
          end
        end
      end
      puts "Successfully generated Plan validation Report2"
    end
  end
end
