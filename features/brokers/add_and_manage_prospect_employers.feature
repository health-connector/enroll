Feature: Create Prospect Employer
  In order for Brokers to create and manage quotes for unassigned employers
  The Broker should be able to add and manage prospect employers on their account

  Background:
    Given a CCA site exists with a benefit market
    Given there is a Broker XYZ
    And the broker is assigned to a broker agency

  Scenario: Create a prospect employer with required information only
    Given that a user with a Broker role exists and is logged in
    When the broker clicks on I'm a Broker
    And the user is on the Employers page of XYZ Broking
    When the user clicks on the Add Prospect Employer button
    And all required fields have valid inputs on the Prospect Employer Form
    And the broker clicks on the Confirm button
    Then the Broker should be on the Employers page of XYZ Broking
    And the user should see a success message

  Scenario: Edit existing prospect employer
    Given that a user with a Broker role exists and is logged in
    And the broker clicks on I'm a Broker
    And the user is on the Employers page of XYZ Broking
    And the broker has a prospect employer
    When the user selects Edit Employer under actions dropdown on an existing prospect
    And the user modifies the Legal Name
    And the broker clicks on the Confirm button
    Then the Broker should be on the Employers page of XYZ Broking
    And the user should see a success message

  Scenario: Attempt to delete a prospect employer with an existing quote
    Given that a user with a Broker role exists and is logged in
    And the broker clicks on I'm a Broker
    And the user is on the Employers page of XYZ Broking
    And the broker has a prospect employer
    And there is a quote for ABC Prospect named ‘Prospect Benefits’
    When the user selects Remove Employer under actions dropdown on an existing prospect
    Then the Broker should be on the Employers page of XYZ Broking
    And the user should see a validation error message

  Scenario: Remove a quote from an existing prospect
    Given that a user with a Broker role exists and is logged in
    And the broker clicks on I'm a Broker
    And the user is on the Employers page of XYZ Broking
    And the broker has a prospect employer
    And there is a quote for ABC Prospect named 'Prospect Benefits’
    When the user selects ‘View Quotes’ on ‘ABC Prospect’
    And the user selects Remove Quote on the quote named ‘Prospect Benefits’
    Then the Broker should be on the Quotes page of ABC Prospect
    And the user should see a success message

  Scenario: Attempt to delete a prospect employer with no quotes
    Given that a user with a Broker role exists and is logged in
    And the broker clicks on I'm a Broker
    And the user is on the Employers page of XYZ Broking
    And the broker has a prospect employer
    And there are no quotes for ‘ABC Prospect’
    When the user selects Remove Employer under actions dropdown on an existing prospect
    Then the Broker should be on the Employers page of XYZ Broking
    And the user should see a success message