When(/^. go(?:es)? to the documents tab$/) do
  find('.interaction-click-control-documents').click
#interaction-click-control-documents
#visit employers_employer_profile_path(employer.employer_profile)+"?tab=documents"
end

When(/^the admin goes to the documents tab directly$/) do
  #interaction-click-control-documents
  visit exchanges_hbx_profiles_path+'?tab=documents'
end

Then(/^the admin should see upload button$/) do
  expect(page).to have_content('Upload')
end

When(/^the admin clicks upload button$/) do
  find('#upload > a').click
end
#
Then(/^the admin should see model box with file upload$/) do
  expect(page).to have_content('SELECT FILE TO UPLOAD')
end


Then(/^the admin fill the document form$/) do
  Capybara.ignore_hidden_elements = false

  script = "$('[name=\"file\"]').css({opacity: 100, display: 'block'});"
  page.evaluate_script(script)

  find(:xpath,"//*[@id='modal-wrapper']/div/form/label").trigger('click')
  within '#new_document' do
    attach_file('file', "#{Rails.root}/test/JavaScript.pdf")
    #find("#document_creator").set Organization.all_employer_profiles.first.try(:legal_name)
  end
  Capybara.ignore_hidden_elements = true
end

Then(/^the admin clicks the upload button in popup/) do
  skip_this_scenario
  click_button('Upload')
end

Then(/^the admin should see the document list/) do
  skip_this_scenario
  wait_for_ajax
  expect(page).to have_content('JavaScript.pdf')
  expect(page).to have_content('Submitted')
end

And(/^the admin clicks document type/) do
  skip_this_scenario
  find(:xpath,"//*[@id='effective_datatable_wrapper']/div/div/div[3]/div/table/tbody/tr[1]/td[4]/a").trigger('click')
end

Then(/^the admin should see Download,Cancel,Print Option/) do
  skip_this_scenario
  wait_for_ajax
  expect(page).to have_content('Cancel')
  expect(page).to have_content('Download')
  expect(page).to have_content('Print')
end