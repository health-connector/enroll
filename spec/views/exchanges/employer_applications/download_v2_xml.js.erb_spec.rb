# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "exchanges/employer_applications/download_v2_xml.js.erb", dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  before :each do
    assign :benefit_sponsorship, benefit_sponsorship
    assign :employer_actions_id, initial_application.id.to_s
    assign :success_message, "V2 XML downloaded successfully."
    assign :file_data, nil
    render template: "exchanges/employer_applications/download_v2_xml", formats: [:js]
  end

  it "anchors the result row to the application's v2 xml inputs row" do
    expect(rendered).to match(/\$\("#v2_xml_inputs_#{initial_application.id}"\)/)
  end

  it "clears only prior result rows, never the wrapper row holding the applications table" do
    expect(rendered).to match(/\$\('tr\.v2-xml-result-row'\)\.remove\(\)/)
    expect(rendered).not_to match(/\$\('tr\.child-row(:visible)?'\)\.remove\(\)/)
  end

  it "inserts the result row with its own class rather than reusing child-row" do
    expect(rendered).to match(/\$anchor_row\.after\('<tr class="v2-xml-result-row"/)
    expect(rendered).not_to match(/after\('<tr class="child-row"/)
  end

  it "always inserts the latest result instead of skipping when one already exists" do
    expect(rendered).not_to match(/hasClass\('child-row'\)/)
  end

  context "when a generated file is present" do
    before :each do
      assign :file_data, Base64.strict_encode64("zip bytes")
      assign :file_name, "TEST_20260807_20260807.zip"
      render template: "exchanges/employer_applications/download_v2_xml", formats: [:js]
    end

    it "embeds the already encoded data rather than reading the file from the view" do
      expect(rendered).to match(/atob\('#{Regexp.escape(Base64.strict_encode64('zip bytes'))}'\)/)
    end

    it "names the download without the stray path prefix" do
      expect(rendered).to match(/link\.download = "TEST_20260807_20260807\.zip"/)
      expect(rendered).not_to match(%r{split\("/"\)})
    end

    it "scopes its declarations so a repeat download does not abort on redeclaration" do
      expect(rendered).to match(/\(function\(\) \{/)
      expect(rendered).to match(/\}\)\(\);/)
    end
  end
end
