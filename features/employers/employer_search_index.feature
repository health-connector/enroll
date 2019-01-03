Feature: As an admin,
  when I am on the employers index page,
  then I should be to accurately search employers.

  Background: Setup site, Employer, HBX staff, Broker, and benefit application
    Given a CCA site exists with a benefit market
    And there are 6 Employers present
    And these employers have a benefit application
    And these benefit applications have a benefit package containing health benefits

    Scenario: Applicants Search Filter
    Given that a user with a HBX staff role with Super admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks the Applicants filter
    Then the user should only see employers with applicant Plan Years.
