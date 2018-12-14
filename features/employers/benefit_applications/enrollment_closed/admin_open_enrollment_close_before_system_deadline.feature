Feature: As an admin user I should have the ability to extend the OE
  of a given Employer before open enrollment has closed.

  Background: Setup site, employer, and enrollment_extended benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a enrollment_extended benefit application
    And this benefit application has a benefit package containing health benefits

    Scenario: Initial application Manual Close
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
	And the system date is greater than or equal to open enrollment end date
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Close Open Enrollment button

    Scenario: Renewing application Manual Close
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
	And the system date is greater than or equal to open enrollment end date
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Close Open Enrollment button
