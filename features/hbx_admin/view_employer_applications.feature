Feature: View Employer Applications by Admin UI

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role

  Scenario: Employer has Expired Draft Application
    Given initial employer ABC Widgets has expired benefit application with terminated on draft_py_effective_on
    And that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    And the user clicks Action for that Employer
    And the user clicks the Plan Years button
    Then the user should see the expired application
