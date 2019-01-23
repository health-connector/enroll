module UserWorld

  def employee(employer=nil)
    if @employee
      @employee
    else
      employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer.profiles.first.id)
      person = FactoryGirl.create(:person, employer_staff_roles:[employer_staff_role])
      @employee = FactoryGirl.create(:user, :person => person)
    end
  end

  def broker(broker_agency=nil)
    if @broker
      @broker
    else
      person = FactoryGirl.create(:person)
      broker_role = FactoryGirl.build(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, person: person)
      @broker = FactoryGirl.create(:user, :person => person)
    end
  end

  def admin(subrole)
    if @admin
      @admin
    else
      subrole = subrole.parameterize.underscore
      hbx_profile_id = FactoryGirl.create(:hbx_profile).id
      person = FactoryGirl.create(:person)
      if subrole.blank?
        raise "No subrole was provided"
      end
      if Permission.where(name:subrole).present?
        permission_id = Permission.where(name:subrole).first.id
      else
        raise "No permission was found for subrole #{subrole}"
      end
      hbx_staff_role = HbxStaffRole.create!( person: person, permission_id: permission_id, subrole: subrole, hbx_profile_id: hbx_profile_id)
      @admin = FactoryGirl.create(:user, :person => person)

    end
  end

end

World(UserWorld)

Given(/^that a user with a (.*?) role(?: with (.*?) subrole)? exists and is logged in$/) do |type, subrole|
  case type
    when "Employer"
      user = employee(employer)
    when "Broker"
      user = broker(broker_agency_profile)
    when "HBX staff"
      user = admin(subrole)
  end
  login_as(user, :scope => :user)
end

And(/^the user is on the Employer Index of the Admin Dashboard$/) do
  visit exchanges_hbx_profiles_path
  find('.interaction-click-control-employers').click
end

And(/^the user is on the Employers page of the Broker Portal$/) do
  expect(page.current_path.include?("employers")).to eq true
end

And(/^the user is on the roster page of the prospect employer page quote$/) do
  visit sponsored_benefits.new_organizations_plan_design_proposal_plan_selection_path(broker_quote)
end

And(/^the user is on the Add Prospect Employer Page$/) do
  url = "/sponsored_benefits/organizations/plan_design_organizations/new?broker_agency_id=#{broker_agency_profile.id}"
  visit url
end

Then(/^the user will see the Extend Open Enrollment button$/) do
  expect(page).to have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

Then(/^the user will not see the Extend Open Enrollment button$/) do
  expect(page).to_not have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

Then(/^the user enters a new open enrollment end date$/) do
  input = find('input.hasDatepicker')
  input.set(Date.today+1.week)
end

And(/^the user should see a new record added to the roster$/) do
  # fill_in_add_employee_form in forms_world.rb
  expect(page).to have_content("Employee Roster")
  expect(page).to have_content("Robert Downey Jr")
  expect(page).to have_content("01/01/1965")
  expect(page).to have_content("Eligible")
end

Then(/^the user should be on the Select Health Benefits page$/) do
  expect(page).to have_content("Benefit Model Selection")
  expect(page).to have_content("Benefit Package Selection")
end

And(/^the user selects (.*?) from the carrier selection list$/) do |plan_name|
  Capybara.ignore_hidden_elements = false
  # All of the plan options are h3 elements with a class of pdp-titles-text.
  # clicking them will select the option
  # For the first test case we are trying to pass through Harvard Pilgrim Health Care 
  binding.pry
  Capybara.ignore_hidden_elements = true
end

When(/^the user selects (.*?) for the (.*?) contribution$/) do |percentage, contributor|
  Capybara.ignore_hidden_elements = false
  inputs = page.all('input')
  sliders = inputs.select { |input| input[:class] == "contribution_slide_handler" }
  Capybara.ignore_hidden_elements = true
  case contributor
  when 'employee'
    Capybara.ignore_hidden_elements = false
    binding.pry
    fill_in(sliders[0], with: percentage.to_s)
    Capybara.ignore_hidden_elements = true
  when 'spouse'
    Capybara.ignore_hidden_elements = false
    fill_in(sliders[1], with: percentage.to_s)
    Capybara.ignore_hidden_elements = true
  when 'domestic partner'
    Capybara.ignore_hidden_elements = false
    fill_in(sliders[2], with: percentage.to_s)
    Capybara.ignore_hidden_elements = true
  when 'child'
    Capybara.ignore_hidden_elements = false
    fill_in(sliders[3], with: percentage.to_s)
    Capybara.ignore_hidden_elements = true
  end
end


When(/^the user selects Single Carrier$/) do
  Capybara.ignore_hidden_elements = false
  # On the UI, selecting the "Div" will then select a hidden
  # radio button
  div_array = page.all('div').to_a
  select_single_carrier = div_array.detect { |div| div.text == 'One Carrier' }
  select_single_carrier.click
  #fail if single_carrier_input.nil?
  binding.pry
  Capybara.ignore_hidden_elements = true
end

Then(/^the user should see a success message confirming creation of the (.*?)$/) do |model_name|
  case model_name
  when 'quote'
    wait_for_ajax
    expect(page).to have_content("Quote information saved successfully.")
  when 'employee'
    wait_for_ajax
    expect(page).to have_content('Employee record created successfully.')
  end
end

When(/^the user clicks (.*?)$/) do |which_link_or_button|
  case which_link_or_button
  when 'Select Health Benefits'
    links = page.all('a')
    link = links.detect { |link| link.text == "Select Health Benefits" }
    link.trigger('click')
  when 'Extend Open Enrollment'
    find('.btn.btn-xs', text: 'Extend Open Enrollment').click
  when 'Extend Open Enrollment button'
    find('input[value="Extend Open Enrollment"]').trigger('click')
  when 'Edit Open Enrollment'
    find('a.btn.btn-primary.btn-sm', text: 'Edit Open Enrollment').trigger('click')
  when 'Action for that Employer'
    find('.dropdown.pull-right', text: 'Actions').click
  when 'the Add Employee button'
    wait_for_ajax
    Capybara.ignore_hidden_elements = false
    links = page.all('a')
    add_employee_link = links.detect { |link| link.text == "Add Employee" }
    add_employee_link.trigger('click')
    Capybara.ignore_hidden_elements = true
  when 'Action for that Employer'
    find('.dropdown.pull-right', text: 'Actions').click
  when "the ‘Create Quote’ option for a prospect employer"
    click_link 'Create Quote'
  end
end