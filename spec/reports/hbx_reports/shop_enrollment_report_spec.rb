# frozen_string_literal: true

require "rails_helper"
require 'csv'
require File.join(Rails.root, "app", "reports", "hbx_reports", "shop_enrollment_report")

describe ShopEnrollmentReport do
  subject { ShopEnrollmentReport.new("shop_enrollment_report", double(:current_scope => nil)) }

  before(:each) do
    subject.migrate
    @file = "#{Rails.root}/hbx_report/shop_enrollment_report.csv"
  end

  it "creates csv file" do
    ClimateControl.modify purchase_date_start: (0o6 / 0o1 / 2018).to_s, purchase_date_end: (0o6 / 10 / 2018).to_s do
      file_context = CSV.read(@file)
      expect(file_context.size).to be > 0
    end
  end

  it "returns correct fields" do
    ClimateControl.modify purchase_date_start: (0o6 / 0o1 / 2018).to_s, purchase_date_end: (0o6 / 10 / 2018).to_s do

      CSV.foreach(@file) do |csv|
        expect(csv).to eq ['Employer ID', 'Employer FEIN', 'Employer Name', 'Employer Rating Area', 'Employer Plan Year Start Date', 'Plan Year State', 'Employer State', 'Enrollment Group ID',
                           'Enrollment Purchase Date/Time', 'Coverage Start Date', 'Enrollment State', 'Subscriber HBX ID', 'Subscriber First Name','Subscriber Last Name', 'Subscriber SSN',
                           'Plan HIOS Id', 'Is PVP Plan', 'Covered lives on the enrollment', 'Enrollment Reason', 'In Glue']
      end
    end
  end

  after(:all) do
    FileUtils.rm_rf(Dir["#{Rails.root}/hbx_report"])
  end
end
