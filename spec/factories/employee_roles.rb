FactoryGirl.define do
  factory :employee_role do
    # association :person, ssn: '123456789', dob: "1/1/1965", gender: "female", first_name: "Sarah", last_name: "Smile"
    association :person
    employer_profile_id { create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site).id }
    sequence(:ssn, 111111111)
    gender "male"
    dob  {Date.new(1965,1,1)}
    hired_on {20.months.ago}

  end

end
