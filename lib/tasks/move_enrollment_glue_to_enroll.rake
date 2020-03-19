# This rake task is to change the attributes on enrollment
# RAILS_ENV=production bundle exec rake migrations:move_enrollment_glue_to_enroll  market="shop"

namespace :migrations do
  desc 'changing attributes on enrollment'
  task :move_enrollment_glue_to_enroll => :environment do
    market = ENV['market']

    Dir.glob("#{Rails.root}/sample_xmls/*.xml").each do |file_path|
      begin
        individual_parser = Parsers::Xml::Cv::Importers::EnrollmentParser.new(File.read(file_path))
        other_enrollment = individual_parser.get_enrollment_object

        enrollment_service = Services::EnrollmentService.new
        enrollment_service.other_enrollment = other_enrollment
        enrollment_service.market = market
        enrollment_service.process

      rescue StandardError => e
        puts "Failed.....#{file_path}--#{e.inspect}"
      end
    end
  end
end
