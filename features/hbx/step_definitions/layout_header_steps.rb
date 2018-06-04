When(/^the Hbx Admin clicks on the logo link$/) do
  find(:xpath, '//*[@id="ma_logo"]/img').trigger('click')
end

Then(/^it should redirect to Health Care Website$/) do
  wait_for_ajax(3,2)
  expect(page).to have_content("#{Settings.site.short_name}")
end