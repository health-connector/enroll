Given(/^the (.*?) is on the (.*?) of the (.*?) employer portal$/) do |role, action, org|
  case action
    when "Benefits page"
      visit benefit_sponsors.profiles_employers_employer_profile_path(employer_profile, :tab => "benefits")
      expect(page).to have_css('.heading-text', text: 'Benefits - Coverage You Offer')
  end
end

When(/^the user clicks 'Publish Plan Year'$/) do
  act_as(@current_role)
  find('.interaction-click-control-publish-plan-year').click
end

Then(/^the benefit application should move to the enrolling state$/) do
  act_as(@current_role)
  find('.alert.alert-notice', text: "Plan Year successfully published.")
end
