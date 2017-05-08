require 'rails_helper'

RSpec.describe "insured/employee_roles/privacy.html.erb" do
  let(:person) {FactoryGirl.create(:person)}
  let(:your_information) { FactoryGirl.create(:translation, key: "en.insured.your_information", value: '"Your Information"') }
  let(:continue) { FactoryGirl.create(:translation, key: "en.continue", value: '"Continue"') }

  before :each do
    assign(:person, person)
    render template: "insured/employee_roles/privacy.html.erb"
  end

  it "should display the employee privacy message" do
    expect(rendered).to have_selector('h1', text: "#{l10n('insured.your_information')}")
    # expect(rendered).to have_selector("strong", text: 'Please read the information below and click the')
    # expect(rendered).to match(/Your answers on this application will only be/i)
    expect(rendered).to have_selector('.btn', text: "#{l10n("continue").to_s.upcase}")
  end
end
