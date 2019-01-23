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

When(/^the broker clicks on I'm a Broker$/) do
  visit "/"
  links = page.all('a')
  link = links.detect { |link| link.text == "I'm a Broker" }
  link.click
end

And(/^the user is on the Employers page of XYZ Broking$/) do
   find('a.interaction-click-control-employers', text: 'Employers').trigger('click')
end

When(/^the user clicks on the Add Prospect Employer button$/) do
  find('a.prospective-employer', text: 'Add Prospect Employer').click
end

And(/^the user enters a Legal Name$/) do
  find('.dropdown.pull-right', text: 'Actions').click
end

When(/^the user clicks Action for that Employer$/) do
  find('.dropdown.pull-right', text: 'Actions').click
end

Then(/^the user will see the Extend Open Enrollment button$/) do
  expect(page).to have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

Then(/^the user will not see the Extend Open Enrollment button$/) do
  expect(page).to_not have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

When(/^the user clicks Extend Open Enrollment$/) do
  find('.btn.btn-xs', text: 'Extend Open Enrollment').click
end

When(/^the user clicks Edit Open Enrollment$/) do
  find('a.btn.btn-primary.btn-sm', text: 'Edit Open Enrollment').trigger('click')
end

Then(/^the user clicks Extend Open Enrollment button$/) do
  find('input[value="Extend Open Enrollment"]').trigger('click')
end

Then(/^the user enters a new open enrollment end date$/) do
  input = find('input.hasDatepicker')
  input.set(Date.today+1.week)
end

And(/^the user is on the Employer Registration page$/) do
  visit '/'
  find('.btn.btn-default.interaction-click-control-employer-portal').click
end

And(/^the broker clicks on the Confirm button$/) do
  page.find_button("Confirm").click
end

Then(/^the Broker should be on the Employers page of XYZ Broking$/) do
  find('a.interaction-click-control-employers', text: 'Employers').trigger('click')
end

And(/^the user should see a success message$/) do 
  expect(page).to have_content("Prospect Employer")
end

When(/^the user selects Edit Employer under actions dropdown on an existing prospect$/) do
  find('a.interaction-click-control-edit-employer-details', text: 'Edit Employer Details').trigger('click')
end

When(/^the user modifies the Legal Name$/) do
  fill_in 'organization_legal_name', with: "123Employer"
end

When(/^the user selects Remove Employer under actions dropdown on an existing prospect$/) do
  find('a.interaction-click-control-remove-employer', text: 'Remove Employer').trigger('click')
end

Then(/^the user should see a validation error message$/) do
  expect(page).to have_content("Please remove any quotes for this employer before removing.")
end

When(/^the user selects ‘View Quotes’ on ‘ABC Prospect’$/) do
  find('a.interaction-click-control-view-quotes', text: 'View Quotes').trigger('click')
end

When(/^the user selects Remove Quote on the quote named ‘Prospect Benefits’$/) do
  find('a.btn', text: 'Remove Quote').trigger('click')
end

Then(/^the Broker should be on the Quotes page of ABC Prospect$/) do
  expect(page).to have_content("Manage Quotes")
end

Given(/^there are no quotes for ‘ABC Prospect’$/) do
  find('a.interaction-click-control-view-quotes', text: 'View Quotes').trigger('click')
  expect(page).to have_content("No data available in table")
  find('a.interaction-click-control-employers', text: 'Employers').trigger('click')
end
