# frozen_string_literal: true

def import_employee(in_file)
  config = YAML.unsafe_load(File.read("#{Rails.root}/conversions.yml"))
  result_file = File.open(File.join(Rails.root, "conversion_employee_policy_results", "RESULT_#{File.basename(in_file)}.csv"), 'wb')
  importer = if Settings.site.key == :mhc
               Importers::Mhc::ConversionEmployeePolicySet.new(in_file, result_file, config["conversions"]["employee_policies_date"], config["conversions"]["employee_policy_year"])
             else
               Importers::ConversionEmployeePolicySet.new(in_file, result_file, config["conversions"]["employee_policies_date"], config["conversions"]["employee_policy_year"])
             end
  importer.import!
  result_file.close
end

dir_glob = File.join(Rails.root, "conversion_employees", "*.{xlsx,csv}")
Dir.glob(dir_glob).each do |file|
  puts "PROCESSING...#{file}"
  import_employee(file)
end
