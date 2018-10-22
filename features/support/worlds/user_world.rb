module UserWorld
  
  def create_poc
    @person ||= FactoryGirl.build(:person, employer_staff_roles:[@employer_staff_role])
    @employer_staff_role ||= FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: @employer_profile.id)
  end
  
  def assign_user
    @user ||= FactoryGirl.build(:user, :person => @person)
  end
end

World(UserWorld)

Given(/^that a user with an (.*?) role exists and is logged in$/) do |type|
  case type
    when "Employer"
      create_poc
      assign_user
  end
  login_as @user
end