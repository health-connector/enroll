# frozen_string_literal: true

require 'csv'
require "rails_helper"
require File.join(Rails.root, "app", "reports", "outstanding_types_report")

describe OutstandingTypesReport do
  subject { OutstandingTypesReport.new("outstanding_types_report", double(:current_scope => nil)) }

  before do
    subject.migrate
    @file = "#{Rails.root}/app/reports/outstanding_types_report.csv"
  end

  after do
    File.delete(@file)
  end

  it "creates csv file" do
    file_context = CSV.read(@file)
    expect(file_context.size).to be > 0
  end

  it "returns correct fields" do
    CSV.foreach(@file, :headers => true) do |csv|
      expect(csv).to eq %w[SUBSCRIBER_ID MEMBER_ID FIRST_NAME LAST_NAME VERIFICATION_TYPE TRANSITION OUTSTANDING DUE_DATE IVL_ENROLLMENT SHOP_ENROLLMENT]
    end
  end
end
