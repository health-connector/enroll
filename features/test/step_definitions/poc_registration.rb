Given(/^the employee is on the (.*?) of the (.*?) employer portal$/) do |action, org|
  case action
    when "Benefits page"
      visit benefit_sponsors.profiles_employers_employer_profile_path(employer_profile, :tab => "benefits")
      expect(page).to have_css('.heading-text', text: 'Benefits - Coverage You Offer')
  end
end

When(/^the user clicks 'Publish Plan Year'$/) do
  find('a.interaction-click-control-publish-plan-year').trigger 'click'
end

Then(/^the benefit application should move to the enrolling state$/) do
  find('h1.heading-text', text: "Employee Roster")
end
