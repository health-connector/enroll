# frozen_string_literal: true

# This task is to mark premium value products in given rating areas
module Products
  class MarkPremiumValueProductsInRatingAreas < MongoidMigrationTask
    def migrate
      file_name = ENV['file_name'].to_s

      CSV.foreach("#{Rails.root}/#{file_name}", headers: true) do |row|
        params = {
          active_year: row["ActiveYear"].to_i,
          hios_id: row["HiosId"],
          rating_area_code: row["RatingAreaCode"].to_s,
          evidence_value: row["PvpEligibility"].to_s,
          updated_by: row["UserEmail"]
        }

        result = ::BenefitMarkets::Operations::Pvp::MarkPvpEligibleInRatingArea.new.call(params)

        if result.success?
          puts "PVP eligibilities got created for #{params}"
        else
          puts "Failed to create PVP eligibilities for params: #{params} due to #{result.failure}"
        end
      end
    end
  end
end
