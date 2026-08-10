# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "exchanges/employer_applications/new_v2_xml.js.erb", dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  before :each do
    assign :application, initial_application
    assign :benefit_sponsorship, benefit_sponsorship
    render template: "exchanges/employer_applications/new_v2_xml", formats: [:js]
  end

  it "does not target a blank selector" do
    expect(rendered).not_to match(/\$\("#"\)/)
  end

  it "anchors the result row to the application's v2 xml inputs row" do
    expect(rendered).to match(/\$\("#v2_xml_inputs_#{initial_application.id}"\)/)
  end

  it "clears only prior result rows, never the wrapper row holding the applications table" do
    expect(rendered).to match(/\$\('tr\.v2-xml-result-row'\)\.remove\(\)/)
    expect(rendered).not_to match(/\$\('tr\.child-row(:visible)?'\)\.remove\(\)/)
  end

  it "inserts the result row with its own class rather than reusing child-row" do
    expect(rendered).to match(/\$anchorRow\.after\('<tr class="v2-xml-result-row"/)
    expect(rendered).not_to match(/after\('<tr class="child-row"/)
  end

  it "always inserts the latest result instead of skipping when one already exists" do
    expect(rendered).not_to match(/hasClass\('child-row'\)/)
  end
end
