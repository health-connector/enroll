require 'pry'

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

When(/^the user clicks Action for that Employer$/) do
  find('.dropdown.pull-right', text: 'Actions').click
end

And(/^the user is on the (.*?) Benefit Application page for this employer$/) do |which_page|
  case which_page
    when "Edit"
      benefit_application_url = "/benefit_sponsors/profiles/employers/employer_profiles/#{employer_profile.id}?tab=benefits"
      visit benefit_application_url
    when "Dental"
      # Technically an "And" statement should not involve any user actions, except for perhaps using the "visit" method
      # to go to a specific URL. However, at the moment, this appears to be the quickest way to get to this page, as the
      # URL is quite complex.
      click_button "Add Dental Benefits"
    end
end

When(/^the user clicks the Benefits page link$/) do
  click_link "Benefits"
end

And(/^the user is on the (.*?) page for this employer$/) do |which_page|
  case which_page
    when "Employer Profile"
      employer_profile_url = "/benefit_sponsors/profiles/employers/employer_profiles/#{employer_profile.id}?tab=home"
      visit employer_profile_url
    end
end

And(/^the only benefit application is in a draft state$/) do

end

When(/^there are zero existing benefit applications$/) do
  # Figure out what user interactions triggers this
  # It's a "When", so it must be a user action.
end

Then(/^the user (.*?) an active Add Plan Year button.$/) do |will_or_will_not|
  # Get more exact CSS of this to check for enabled button
  case will_or_will_not
    when 'will see'
      expect(page).to have_link("Add Plan Year"), disabled: false
    when 'will not see'
      expect(page).not_to have_link("Add Plan Year"), disabled: false
    end
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
