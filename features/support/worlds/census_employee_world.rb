module CensusEmployeeWorld
  def census_employees(roster_count = 1, *traits)
    attributes = traits.extract_options!
    @census_employees ||= FactoryGirl.create_list(:census_employee, roster_count, attributes)
  end
end
World(CensusEmployeeWorld)

And(/^there (are|is) (\d+) (employee|employees) for (.*?)$/) do |_, roster_count, _, legal_name|
  sponsorship = employer(legal_name).benefit_sponsorships.first
  census_employees roster_count.to_i, benefit_sponsorship: sponsorship, employer_profile: sponsorship.profile
end
