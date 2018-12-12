Given(/^I am a valid user$/) do
  create_user
end

When(/^I complete the Sign In form$/) do
  visit user_session_path
  fill_in "user_login", :with => user.email
  fill_in "user_password", :with => user.password
  click_button "Sign in"
end

Then(/^I should see the welcome page$/) do
  page.should have_content('Signed in successfully.')
end

