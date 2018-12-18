Feature: As an employer/admin/broker
  I want to add dental benefits to an existing benefit package
  So that I can offer dental coverage to my employees.

  Background: Setup site, Employer, HBX staff, Broker and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a draft benefit application
    And this benefit application has a benefit package containing health and benefits

    Scenario: Creation/EDIT of benefit package
    Given that a user with a Employer role exists and is logged in
    And the user is on the Edit Benefit Application page for this employer
    When the user goes to edit the Plan Year
    Then the user will see an enabled button labeled Add Dental Benefits

    Scenario: Navigation to Dental Set Up
    Given that dental products exist
    Given that a user with a Employer role exists and is logged in
    And the user is on the Edit Benefit Application page for this employer
    When the user goes to edit the Plan Year
    And the user is on the Dental Benefit Application page for this employer
    Then the user will see a heading Dental Set up Benefit Package
    And the existing Health Benefit should be saved