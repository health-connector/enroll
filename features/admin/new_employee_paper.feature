Feature: Phone and Paper Enrollment options exist
  In order to support paper enrollments
  Link is provided that will track paper enrollment

   Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given Qualifying life events are present
    And benefit market has prior benefit market catalog
    And there is an employer ABC Widgets

  Scenario Outline: Phone and Phone Enrollment
    Given that a user with a HBX staff role with <subrole> subrole exists and is logged in
    And the user is on the Family Index of the Admin Dashboard
    Then I see the Paper link
    And user will click on New Employee Paper Application link
    Then HBX admin start new employee enrollment

    Examples:
      | subrole       | action  |
      | Super Admin   | see     | 
      | HBX Tier3     | see     |
      | HBX Staff     | see     |
      | HBX Read Only | not see |
