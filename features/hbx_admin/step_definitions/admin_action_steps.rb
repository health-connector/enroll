# frozen_string_literal: true

Then(/^the user should see the (.*) application$/) do |aasm_state|
  expect(find_all(AdminHomepage.application_status).first.text.downcase).to eq aasm_state.downcase
end
