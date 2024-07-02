# frozen_string_literal: true

Then(/^the user should see the (.*) application$/) do |aasm_state|
  expect(find_all(AdminHomepage.application_status).first.text.downcase).to eq aasm_state.downcase
end

Then(/^the user visits the orphan accounts page$/) do
  find(AdminHomepage.admin_dropdown).click
  find(AdminHomepage.orphan_accounts).click
end

Then(/^the user should see the orphan accounts page$/) do
  expect(page).to have_content(l10n('users.orphans.index.orphan_user_accounts'))
end

Then(/^the user navigates directly to the orphan accounts page$/) do
  visit "/users/orphans"
end

Then(/^the user should not see the orphan accounts page$/) do
  expect(page).to have_content('user_policy.staff_can_access_user_account_tab?')
end
