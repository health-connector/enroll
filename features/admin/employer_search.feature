Feature: Add search functionality for admin to search employer
  In order for the Hbx admin to search for employers through searchbox

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a enrollment_open benefit application
    And this benefit application has a benefit package containing health benefits

  Scenario: HBX Staff with Super Admin subroles should see Change FEIN button
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    When the user enters fein of employer ABC Widgets in search bar
    Then the user will see ABC Widgets Employer
    And the user will not see XYZ Widgets Employer