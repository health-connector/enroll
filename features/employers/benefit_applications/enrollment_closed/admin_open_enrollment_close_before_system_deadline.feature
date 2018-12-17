Feature: As an admin user I should have the ability to extend the OE
  of a given Employer before open enrollment has closed.

  Background: Setup site, employer, and enrolling/renewing benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a enrolling benefit application
    And this employer has a enrollment_open benefit application
    And this employer has a enrollment_extended benefit application
    And this benefit application has a benefit package containing health benefits

    Scenario: Initial application Manual Close
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
	And the system date is greater than or equal to open enrollment start date
	And the system date is less than or equal to open enrollment end date
    When the user clicks Action for that Employer
    Then the user will not see the Close Open Enrollment button

    Scenario: Renewing application Manual Close
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
	And the system date is greater than or equal to open enrollment start date
	And the system date is less than or equal to open enrollment end date
    When the user clicks Action for that Employer
    Then the user will not see the Close Open Enrollment button