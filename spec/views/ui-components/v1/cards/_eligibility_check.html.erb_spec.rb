require "rails_helper"

RSpec.describe "ui-components/v1/cards/_eligibility_check.html.slim" do
  context "when the eligibility partial is rendered" do

    let(:employer_profile) do
      instance_double(
        "EmployerProfile"
      )
    end

    before do
      # Extend view with necessary url helpers
      view.extend BenefitSponsors::Engine.routes.url_helpers
      
      # Mock EmployerProfile and assign it to view's instance variable
      employer_profile = instance_double("EmployerProfile", id: 1)
      assign(:employer_profile, employer_profile)
    
      # Render the partial with the assigned employer_profile
      render "ui-components/v1/cards/eligibility_check"
    end

    it "displays the 'Run Eligibility Check' button" do
      expect(rendered).to have_selector('input#eligibilityCheckButton[value="Run Eligibility Check"]')
    end

    it "contains the loading icon with the appropriate classes" do
      expect(rendered).to have_selector(".col-xs-12.loading.run-eligibility-processing.hide i.fa.fa-spinner.fa-spin.fa-2x")
    end

    it "contains the eligibility response container which is hidden by default" do
      expect(rendered).to have_selector('.run-eligibility-check-response-container[style="display: none;"]', visible: false)
    end
    
    it "contains the Minimum Participation status text" do
      expect(rendered).to have_selector("p.eligibility-status-text.minimum-participation", text: "Minimum Participation", visible: false)
    end
    
    it "contains the Non-Business Owner Eligibility Count status text" do
      expect(rendered).to have_selector("p.eligibility-status-text.non-business-owner-eligibility-count", text: "Non-Business Owner Eligibility Count", visible: false)
    end
    
    it "contains the Minimum Eligible Member Count status text" do
      expect(rendered).to have_selector("p.eligibility-status-text.minimum-eligible-member-count", text: "Minimum Eligible Member Count", visible: false)
    end
  end
end
