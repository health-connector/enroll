require File.join(Rails.root, 'lib/mongoid_migration_task')

class GoldenSeed < MongoidMigrationTask
  def migrate
    benefit_sponsorship_id_list = ENV['benefit_sponsorship_ids'].to_s
    coverage_start_on = ENV['coverage_start_on'].to_s
    coverage_end_on = ENV['coverage_end_on'].to_s
    if [benefit_sponsorship_id_list, coverage_start_on, coverage_end_on].any? { |input| input.blank? }
      # TODO
    else
      # TODO
      puts('Executing migration')
    end
  end
end
