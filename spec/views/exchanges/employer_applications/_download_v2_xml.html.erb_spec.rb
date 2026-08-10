# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "exchanges/employer_applications/_download_v2_xml.html.erb", dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  before :each do
    assign :benefit_sponsorship, benefit_sponsorship
    render partial: "exchanges/employer_applications/download_v2_xml", locals: { application: initial_application }
  end

  it "builds the form action with a non blank employer_actions_id" do
    expect(rendered).not_to match(/employer_actions_id=(&|")/)
  end

  it "uses the benefit application id as the employer_actions_id" do
    expect(rendered).to match(/employer_actions_id=#{initial_application.id}/)
  end
end
