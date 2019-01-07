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

  def user_sign_up
    fill_in 'user_oim_id', with: 'employerone@test.com'
    fill_in 'user_password', with: 'P@$$W0rd1'
    fill_in 'user_password_confirmation', with: 'P@$$W0rd1'
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
  visit '/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=benefit_sponsor'
  #visit '/'
  #find('.btn.btn-default.interaction-click-control-employer-portal').click
end

And(/^the user is registering a new Employer$/) do
  registering_employer
end

And(/^the user is on the root index page$/) do
  visit '/'
end

And(/^the user clicks the Employer Portal link$/) do
  find('.interaction-click-control-employer-portal').click
end

And(/^the user has successfully signed up$/) do
  user_sign_up
  find('.interaction-click-control-create-account').click
end

When(/^the user clicks the 'Confirm' button on the Employer Registration Form$/) do
  find('input[name="commit"]').click
end

Then(/^the user will navigate to a new page "My Health Benefits Program"$/) do
  expect(page).to have_css('.alert-notice', text: 'Welcome to Health Connector. Your account has been created.')
end

Then(/^the user will be prompted to enter missing information from the Employer Registration Form$/) do
  expect(page).to have_css('.invalid-feedback', text: 'Please provide a first name.')
  expect(page).to have_css('.invalid-feedback', text: 'Please provide a last name.')
end
