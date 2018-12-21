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
    Given that a user with a Employer role exists and is logged in
    And the user is on the Edit Benefit Application page for this employer
    When the user goes to edit the Plan Year
    And the user is on the Dental Benefit Application page for this employer
    Then the user will be on the Set Up Dental Benefit Package Page
    And the existing Health Benefit should be saved

    Scenario: Employer Contribution Disables the Add Dental Benefits button
    Given that a user with a Employer role exists and is logged in
    And the benefit application is not effective January 1st
    And the user is on the Edit Benefit Application page for this employer
    When the user goes to edit the Plan Year
    And the user sees health edit benefit package
    When the user selects a contribution value less than shop:employer_contribution_percent_minimum
    Then the Add Dental Benefits button should be disabled

    Scenario: Employer Contribution Enables the Add Dental Benefits button
    Given that a user with a Employer role exists and is logged in
    And the benefit application is effective January 1st
    And the user is on the Edit Benefit Application page for this employer
    When the user goes to edit the Plan Year
    And the user sees health edit benefit package
    When the user selects a contribution value less than shop:employer_contribution_percent_minimum
    Then the Add Dental Benefits button should be enabled
