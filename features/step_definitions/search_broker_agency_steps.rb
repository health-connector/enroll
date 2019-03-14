Then(/^Hbx Admin should see search box$/) do
  wait_for_ajax
  page.find("input[type='search']").visible?
end

When(/^he enters an broker agency name and clicks on the search button$/) do
  page.find("input[type='search']").set("ACME Agency")
end

Then(/^he should see the one result with the agency name$/) do
  expect(page).to have_content("ACME Agency")
  expect(page).to have_no_content("Chase & Assoc")
end

Given(/^Hbx Admin clicks on (.*)$/) do |link_text|
  target_link = page.all('a').detect { |a| a.text == link_text }
  target_link.click
end
