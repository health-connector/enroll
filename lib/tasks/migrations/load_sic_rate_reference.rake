namespace :load_sic_rate_reference do
	desc "load sic code from xlsx file"
	task :update_sic_code => :environment do
		begin
			file_path = File.join(Rails.root, 'lib','xls_templates',"SHOP_RateFactors_CY2017_SOFT_DRAFT.xlsx")
			xlsx = Roo::Spreadsheet.open(file_path)
			sheet = xlsx.sheet(0)
      hios_ids = [sheet.cell(2,3),sheet.cell(2,4),sheet.cell(2,5),sheet.cell(2,6)]
      headers = {}
      sheet.row(2).each_with_index do |header,i|
        headers[header] = i
      end
      
      hios_ids.each do |hios_id|
        (3..sheet.last_row).each do |i|
          SicRateReference.create!(
            sic: sheet.cell(i,1),
            hios_id: hios_id.to_i,
            cost_ratio: (sheet.row(i)[headers[hios_id]] || 1.000),
            applicable_year: Time.now.year
          )
          
        end
		  end
	  rescue => e
	  	puts e.inspect
	  end
	end
end