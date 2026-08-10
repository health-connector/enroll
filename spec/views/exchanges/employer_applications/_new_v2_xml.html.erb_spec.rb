# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "exchanges/employer_applications/_new_v2_xml.html.erb", dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  before :each do
    assign :application, initial_application
    assign :benefit_sponsorship, benefit_sponsorship
    render partial: "exchanges/employer_applications/new_v2_xml"
  end

  it "sets a value attribute on the employer_actions_id hidden field" do
    expect(rendered).to match(/name="employer_actions_id" id="employer_actions_id" value="/)
  end

  it "uses the benefit application id as the employer_actions_id" do
    expect(rendered).to match(/id="employer_actions_id" value="#{initial_application.id}"/)
  end
end
