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

Given(/^Hbx Admin click on (.*)$/) do |link_text|
  links = page.all('a')
  spans = page.all('span')
  case link_text
    when 'Broker Agencies'
      links.detect { |link| link.text == "Brokers" }.click
      click_link(link_text)
    else
      page.find('a', /link_text?/i, match: :first).click
  end
end
