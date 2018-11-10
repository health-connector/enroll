module UserWorld

  def employee(employer)
    if @employee
      @employee
    else
      employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer.profiles.first.id)
      person = FactoryGirl.build(:person, employer_staff_roles:[employer_staff_role])
      @employee = FactoryGirl.build(:user, :person => person)
    end
  end
end

World(UserWorld)

Given(/^that a user with an (.*?) role exists and is logged in$/) do |type|
  case type
    when "Employer"
      user = employee(employer)
    when "Broker"
      user = nil
    when "HBX staff"
      user = nil
  end
  login_as user, scope: :user
end
