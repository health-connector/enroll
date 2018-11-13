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
      broker_agency_profile = FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, organization:broker_agency)
      person = FactoryGirl.create(:person)
      broker_role = FactoryGirl.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, person: person)
      @broker = FactoryGirl.create(:user, :person => person)
    end
  end

  def act_as(role)
    case role
    when "employee"
      user = employee(employer)
    when "broker"
      user = broker(employer)
    end
    login_as(user, :scope => :user)
  end

end

World(UserWorld)

Given(/^that a user with a (.*?) role exists and is logged in$/) do |type|
  case type
    when "Employer"
      @current_role = "employee"
    when "Broker"
      @current_role = "broker"
    when "HBX staff"
      user = nil
  end
  act_as(@current_role)
end
