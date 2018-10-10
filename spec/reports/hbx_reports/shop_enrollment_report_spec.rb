require "rails_helper"
require 'csv'
require File.join(Rails.root, "app", "reports", "hbx_reports", "shop_enrollment_report")
require "#{Rails.root}/app/helpers/config/aca_helper"
include Config::AcaHelper

describe ShopEnrollmentReport do |field_name, result|
  subject { ShopEnrollmentReport.new("shop_enrollment_report", double(:current_scope => nil)) }
  let(:given_task_name) { "shop_enrollment_report" }
  let(:publisher) { double }
  let(:time_now) { Time.now }
  let!(:date) { Date.new(2018,1,1) }
  let!(:fixed_time) { Time.parse("Jan 1 2018 10:00:00") }

  before :each do
    allow(TimeKeeper).to receive(:date_of_record).and_return(date)
    allow(TimeKeeper).to receive(:datetime_of_record).and_return(fixed_time)
    @file = File.expand_path("#{Rails.root}/public/CCA_test_ShopEnrollmentReport_2018_01_01_10_00_00.csv")
    allow(Time).to receive(:now).and_return(time_now)
    allow(Publishers::Legacy::ShopEnrollmentReportPublisher).to receive(:new).and_return(publisher)
    allow(publisher).to receive(:publish).with(URI.join("file://", @file))
    subject.migrate
  end

  it "has the given task name" do
    expect(subject.name).to eql given_task_name
  end

  it "correct column headers" do
    csv = CSV.read(@file)
    header = csv[0]
    expect(header).to eq ["Employer ID", "Employer FEIN", "Employer Name", "Employer Plan Year Start Date", "Plan Year State", "Employer State", "Enrollment Group ID", "Enrollment Purchase Date/Time", "Coverage Start Date", "Enrollment State", "Subscriber HBX ID", "Subscriber First Name", "Subscriber Last Name", "Subscriber SSN", "Plan HIOS Id", "Covered lives on the enrollment", "Enrollment Reason", "In Glue"]
  end

  it "creates csv file" do
    file_context = CSV.read(@file)
    expect(file_context.size).to be > 0
  end

  it "returns correct #{field_name} in csv file" do
    CSV.foreach(@file, :headers => true) do |csv_obj|
      expect(csv_obj[field_name]).to eq result
    end
  end

  after(:each) do
    FileUtils.rm_rf(@file)
  end
end