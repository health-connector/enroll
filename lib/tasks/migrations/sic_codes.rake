namespace :seed do
  desc "Load sic codes data"
  task :sic_codes => :environment do
  	files = Dir.glob(File.join(Rails.root, "lib/xls_templates", "sic_codes_ma.xlsx"))
    if files.present?
      results = Roo::Spreadsheet.open(files.first)
      sheet_data = results.sheet("List")
      2.upto(sheet_data.last_row) do |row_number|
      	begin
	      data = sheet_data.row(row_number)
	      @division = data[2] if data[1] == "Division"
	      @major_group = data[2] if data[1] == "Major Group"
	      @industry_group = data[2] if data[1] == "Industry Group"
	      if data[1] == "Code"
	      	SicCode.create!(code: data[2], industry_group: @industry_group, major_group: @major_group, division: @division)
	      end
	      # if data[1] == "Division"
	      # 	# @division = Division.create(:description => data[2])
	      # 	@division = data[1]
	      # elsif @division && data[1] == "Major Group"
	      # 	# @major_group = @division.major_groups.create(:description => data[2])
	      # 	@major_group = data[1]
	      # elsif @major_group && data[1] == "Industry Group"
	      # 	# @industry_group = @major_group.industry_groups.create(:description => data[2])
	      # 	@industry_group = data[1]
	      # elsif @industry_group && data[1] == "Code"
	      # 	# @sic_code = @industry_group.sic_codes.create(:code => data[2])
	      # 	SicCode.create!(code: data[1], industry_group: @industry_group, major_group: @major_group, division: @division, description: data[2])
	      # end
        rescue Exception => e
          puts "#{e.message}"
        end
      end
    end
  end
end