
Then (/^Hbx Admin sees Employees link$/) do
  expect(page).to have_text("Employees")
end

When(/^Hbx Admin click Employees link$/) do
  click_link "Employees"
end

Then(/^Hbx Admin should see an Edit APTC \/ CSR link$/) do
  find_link('Edit APTC / CSR').visible?
end

Then(/^Hbx Admin should not see an Edit APTC \/ CSR link$/) do
  expect(page).to_not have_text("Edit APTC / CSR")
end
