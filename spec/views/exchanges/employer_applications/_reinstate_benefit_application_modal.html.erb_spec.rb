# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "exchanges/employer_applications/_reinstate_benefit_application_modal.html.erb", dbclean: :after_each do

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:family) { FactoryGirl.create(:family, :with_primary_family_member,person: person) }
  let(:user) { FactoryGirl.create(:user, person: person, roles: ["hbx_staff"]) }
  let(:person) { FactoryGirl.create(:person) }
  let(:employer_profile) { benefit_sponsorship.profile }

  before :each do
    sign_in(user)
    assign(:employer_profile, employer_profile)
    assign(:benefit_sponsorship, benefit_sponsorship)
    render "exchanges/employer_applications/reinstate_benefit_application_modal", employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship
    allow(::EnrollRegistry).to receive(:feature_enabled?).with(:benefit_application_reinstate).and_return(true)
  end

  it "should display the modal title" do
    expect(rendered).to have_selector('.modal-title', text: 'Confirm')
  end

  it "should display the confirmation message" do
    expect(rendered).to have_selector('.modal-body h4', text: 'Are you sure you want to reinstate this plan year?')
  end

  it "should have a submit button with the text 'Reinstate Plan Year'" do
    expect(rendered).to have_selector("input[type=submit][value='Yes, Reinstate PY']")
  end

  it "should have a cancel button with the text 'Cancel'" do
    expect(rendered).to have_selector('.btn.btn-default', text: 'Cancel')
  end
end

# To Do
# going to add feature test case instead rspec for this view file