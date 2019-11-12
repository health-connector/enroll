require 'csv'

namespace :sbc do
  desc "Export SBC Keys"
  task :export => :environment do

    field_names  = %w(
      hios_id
      year
      identifier
      title
    )

    file_name = "#{Rails.root}/sbc_keys.csv"

    plans = Plan.all.where(active_year: 2020)

    CSV.open(file_name, "w", force_quotes: true) do |csv|
      csv << field_names
      plans.each do |plan|
        document = plan.sbc_document
        if document
          csv << [
            plan.hios_id,
            2020,
            document.identifier,
            plan.name
          ]
        end
      end
    end
  end
end
