# Can be ran with rake db:builds:complete:all
namespace :db do
  namespace :builds do
    namespace :complete do
      Dir[Rails.root.join('db', 'builds', 'complete', '*.rb')].each do |filename|
        task_name = File.basename(filename, '.rb')
        desc "Seed " + task_name + ", based on the file with the same name in `db/builds/complete/*.rb`"
        task task_name.to_sym => :environment do
          load(filename) if File.exist?(filename)
        end
      end
    end
  end
end
