require "rails_helper"
require 'csv'
require File.join(Rails.root, "app", "data_migrations", "new_hire_effective_on_report")

describe NewHireEffectiveOnReport do
  subject { NewHireEffectiveOnReport.new("new_hire_effective_on_report", double(:current_scope => nil)) }

  before(:each) do
    subject.migrate
    @file1 = "#{Rails.root}/organization_report.csv"
    @file2 = "#{Rails.root}/employee_report.csv"
  end

  it "creates csv file" do
    file_context_1 = CSV.read(@file1)
    file_context_2 = CSV.read(@file2)
    expect(file_context_1.size).to be > 0
    expect(file_context_2.size).to be > 0
  end

  it "returns correct fields for organization report" do
    CSV.foreach(@file1, :headers => true) do |csv|
      expect(csv).to eq field_names = %w('Employer Legal Name', 'Employer FEIN', 'Employer Plan Year Start Date', 'Employer HBX ID')
    end
  end
  it "returns correct fields for employee report" do
    CSV.foreach(@file2, :headers => true) do |csv|
      expect(csv).to eq field_names = %w('Employer Legal Name', 'Employer FEIN', 'Employer Plan Year Start Date', 'Employer HBX ID', 'EE First Name', 'EE Last Name', 'EE HBX ID', 'Enrollment Policy ID', 'Enrollment HIOS ID', 'Enrollment Carrier Name', 'Enrollment Plan Name', 'Enrollment Submitted On Date', 'EE Effective date of coverage', 'EE Date Of Hire','EE Added to roster date')
    end
  end
  after(:all) do
    FileUtils.rm_rf(Dir["#{Rails.root}/organization_report.csv"])
    FileUtils.rm_rf(Dir["#{Rails.root}/employee_report.csv"])
  end
end