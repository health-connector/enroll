# frozen_string_literal: true

require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "employers/employer_profiles/my_account/_enrollment_progress_bar.html.erb" do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application" do
    let(:aasm_state) { :enrollment_open }
  end

  let!(:employer_profile)    { abc_profile }
  let!(:plan_year) { initial_application }


  context "when plan year is 1/1 plan year" do

    before do
      allow(plan_year).to receive(:total_enrolled_count).and_return(1)
      allow(plan_year).to receive_message_chain(:progressbar_enrolled_non_business_owner_members, :count).and_return(1)
      allow(plan_year).to receive(:progressbar_covered_count).and_return(1)
      allow(plan_year).to receive(:waived_count).and_return(0)
    end

    it "should not see enrollment target" do
      assign(:current_plan_year, plan_year)
      render "employers/employer_profiles/my_account/enrollment_progress_bar", :current_plan_year => plan_year
      expect(rendered).to have_selector("divider-progress", count: 0)
    end

  end
end
