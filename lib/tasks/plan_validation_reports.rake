# frozen_string_literal: true

# These rake tasks should be run to generate reports after plans loading.
# To run all reports please use this rake command: RAILS_ENV=production bundle exec rake plan_validation:reports["2019-12-01"]

namespace :plan_validation do

  desc "reports generation after plan loading"
  task :reports, [:active_date] => :environment do |_task, args|
    puts "Reports generation started" unless Rails.env.test?
    puts "Reports generation started for Report1" unless Rails.env.test?
    Rake::Task['plan_validation:report1'].invoke(args[:active_date])
    puts "Reports generation started for Report2" unless Rails.env.test?
    Rake::Task['plan_validation:report2'].invoke(args[:active_date])
    puts "Reports generation started for Report3" unless Rails.env.test?
    Rake::Task['plan_validation:report3'].invoke(args[:active_date])
    puts "Reports generation started for Report4" unless Rails.env.test?
    Rake::Task['plan_validation:report4'].invoke(args[:active_date])
    puts "Reports generation started for Report5" unless Rails.env.test?
    Rake::Task['plan_validation:report5'].invoke(args[:active_date])
    puts "6th Plan validation Report generation started for SIC Codes" unless Rails.env.test?
    Rake::Task['plan_validation:sic_codes'].invoke(args[:active_date])
  end

  #To run first report: RAILS_ENV=production bundle exec rake plan_validation:report1["2020-01-01"]
  desc "Details about Plan Count by Carrier, Coverage and Tier"
  task :report1, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_report1_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName PlanTypeCode Tier Count]
      products = ::BenefitMarkets::Products::Product.by_year(args[:active_date])
      products.all.each do |product|
        active_year = product.active_year
        carrier_id = product.hios_id[0..4]
        carrier_name = product.issuer_profile.abbrev
        plan_type_code = product.kind == :health ? "QHP" : "QDP"
        tier = product.metal_level_kind
        product_count = ::BenefitMarkets::Products::Product.by_year(active_year).where(hios_id: /#{carrier_id}/i, metal_level_kind: tier).count
        csv << [active_year, carrier_id, carrier_name, plan_type_code, tier, product_count]
      end
      puts "Successfully generated Plan validation Report1"
    end
  end

  #To run second report: RAILS_ENV=production bundle exec rake plan_validation:report2["2020-01-01"]
  desc "Rating Area and Age Based Plan Rate Sum"
  task :report2, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_report2_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName RatingArea Age Sum]
      issuer_hios_ids = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten.flat_map(&:issuer_hios_ids).map(&:to_i)

      rating_area_ids = ::BenefitMarkets::Locations::RatingArea.where(active_year: active_year).inject({}) do |data, ra|
        data[ra.id.to_s] = ra.exchange_provided_code
        data
      end

      issuer_hios_ids.each do |issuer_hios_id|
        products = ::BenefitMarkets::Products::Product.by_year(active_year).where(hios_id: /#{issuer_hios_id}/)
        rating_area_ids.each do |rating_area_key, rating_area_value|
          premium_tables = products.map(&:premium_tables).flatten.select do |prem_tab|
            start_date = prem_tab.effective_period.min.to_date
            end_date = prem_tab.effective_period.max.to_date
            (start_date..end_date).cover?(active_date) && prem_tab.rating_area_id.to_s == rating_area_key
          end
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
            csv << [active_year, issuer_hios_id, carrier_name, ra_val, value, age_cost.round(2)]
          end
        end
      end
      puts "Successfully generated Plan validation Report2"
    end
  end

  #To run third report: RAILS_ENV=production bundle exec rake plan_validation:report3["2020-01-01"]
  desc "Service Area based count of Counties, Zip Codes and Plans"
  task :report3, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_report3_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName ServiceAreaCode PlanCount County_Count Zip_Count]
      issuer_hios_ids = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten.flat_map(&:issuer_hios_ids).map(&:to_i)
      all_county_zip_ids = ::BenefitMarkets::Products::Product.by_year(active_year).map(&:service_area).map(&:county_zip_ids).flatten.uniq
      issuer_hios_ids.each do |issuer_hios_id|
        issuer_products = ::BenefitMarkets::Products::Product.by_year(active_year).where(hios_id: /#{issuer_hios_id}/)
        grouped_products = issuer_products.group_by(&:service_area)
        grouped_products.each do |service_area, products|
          if service_area.covered_states == ["MA"]
            county_zip_ids = ::BenefitMarkets::Locations::CountyZip.where(:id.in => all_county_zip_ids)
          else
            ids = service_area.county_zip_ids.flatten.uniq
            county_zip_ids = ::BenefitMarkets::Locations::CountyZip.where(:id.in => ids)
          end
          county_count = county_zip_ids.map(&:county_name).uniq.size
          zip_count = county_zip_ids.map(&:zip).uniq.size
          carrier_name = products.first.issuer_profile.legal_name
          csv << [active_year, issuer_hios_id, carrier_name, service_area.issuer_provided_code, products.size, county_count, zip_count]
        end
      end
      puts "Successfully generated Plan validation Report3"
    end
  end

  #To run fourth report: RAILS_ENV=production bundle exec rake plan_validation:report4["2019-01-01"]
  desc "PlanYearId CarrierId CarrierName GroupSizeSum GroupSizeFactorSum"
  task :report4, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_report4_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName GroupSizeSum GroupSizeFactorSum]
      profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten
      profiles.each do |profile|
        carrier_name = profile.abbrev
        profile_id = profile.id.to_s
        profile.issuer_hios_ids.each do |issuer_hios_id|
          group_sizes = BenefitMarkets::Products::ActuarialFactors::GroupSizeActuarialFactor.all.where(active_year: active_year, issuer_profile_id: profile_id)
          group_sizes.each do |group_size|
            group_size_sum = group_size.actuarial_factor_entries.map(&:factor_key).flatten.inject(0) do |sum,i|
              value = i.to_i
              sum + value
            end
            group_size_factor_sum = group_size.actuarial_factor_entries.map(&:factor_value).flatten.inject(0) { |sum,i| sum + i }
            csv << [active_year, issuer_hios_id, carrier_name, group_size_sum, group_size_factor_sum.round(3)]
          end
        end
      end
      puts "Successfully generated Plan validation Report4"
    end
  end

  #To run fifth report: RAILS_ENV=production bundle exec rake plan_validation:report5["2019-01-01"]
  desc "Planyearid CarrierId CarrierName GroupSizeSum ParticipationRateSum"
  task :report5, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_report5_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName GroupSizeSum ParticipationRateSum]
      profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten
      profiles.each do |profile|
        carrier_name = profile.abbrev
        profile_id = profile.id.to_s
        profile.issuer_hios_ids.each do |issuer_hios_id|
          part_rates = ::BenefitMarkets::Products::ActuarialFactors::ParticipationRateActuarialFactor.all.where(active_year: active_year, issuer_profile_id: profile_id)
          part_rates.each do |part_rate|
            group_size_sum = part_rate.actuarial_factor_entries.map(&:factor_key).flatten.inject(0) do |sum,i|
              value = i.to_i
              sum + value
            end
            participation_rate_sum = part_rate.actuarial_factor_entries.map(&:factor_value).flatten.inject(0) { |sum,i| sum + i }
            csv << [active_year, issuer_hios_id, carrier_name, group_size_sum, participation_rate_sum.round(2)]
          end
        end
      end
      puts "Successfully generated Plan validation Report5"
    end
  end

  #To generate sixth report: RAILS_ENV=production bundle exec rake plan_validation:sic_codes["2021-01-01"]
  desc "SIC Codes Count & Rate Factor Sum"
  task :sic_codes, [:active_date] => :environment do |_task, args|
    active_date = args[:active_date].to_date
    active_year = active_date.year
    CSV.open("#{Rails.root}/plan_validation_sic_codes_#{active_year}.csv", "w", force_quotes: true) do |csv|
      csv << %w[PlanYearId CarrierId CarrierName SIC_Count SICRateSum]
      profiles = BenefitSponsors::Organizations::ExemptOrganization.issuer_profiles.map(&:profiles).flatten
      profiles.each do |profile|
        carrier_name = profile.abbrev
        profile_id = profile.id.to_s
        profile.issuer_hios_ids.each do |issuer_hios_id|
          sic_codes = ::BenefitMarkets::Products::ActuarialFactors::SicActuarialFactor.all.where(active_year: active_year, issuer_profile_id: profile_id)
          sic_codes.each do |sic_code|
            sic_count = sic_code.actuarial_factor_entries.count
            sic_rate_sum = sic_code.actuarial_factor_entries.map(&:factor_value).flatten.inject(0) { |sum,i| sum + i }
            csv << [active_year, issuer_hios_id, carrier_name, sic_count, sic_rate_sum.round(2)]
          rescue StandardError
            puts "#{e.message}, plan validation issue with carrier_name: #{carrier_name} and issuer_hios_id: #{issuer_hios_id}"
          end
        end
      end
      puts "Successfully generated 6th Plan validation report for SIC Codes"
    end
  end
end
