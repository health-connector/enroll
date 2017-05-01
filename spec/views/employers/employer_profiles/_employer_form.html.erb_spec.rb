require "rails_helper"

RSpec.describe "employers/employer_profiles/_employer_form.html.erb" do
  let(:employer_profile) { create(:employer_profile) }
  let(:person) { build(:person) }
  let(:organization) { build(:organization, office_locations: [office_location]) }
  let(:office_location) { build(:office_location, :primary, address: office_address) }
  let(:office_address) { build(:address, city: "Baltimore") }

  before :each do
    allow(organization).to receive(:employer_profile).and_return employer_profile
    allow(view).to receive(:policy_helper).and_return(double("Policy", updateable?: false))
    assign(:employer_profile, employer_profile)
    assign(:organization, organization)
    assign(:employer, person)
    render "employers/employer_profiles/employer_form"
  end

  it "should show title" do
    expect(rendered).to match /Business Info/
  end

  it "should show person info" do
    expect(rendered).to match /Employer Information/
    expect(rendered).to match /Point of Contact - Employer Staff/
    expect(rendered).to match  /Last Name/
  end

  it "should show the office location" do
    expect(rendered).to match /Baltimore/
    expect(rendered).to have_css("fieldset.primary-office-location")
  end
end
