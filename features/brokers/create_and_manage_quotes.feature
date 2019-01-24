Feature: Create and Manage Quotes
  In order for Brokers to be able to send a quote to an employe to claim
  The broker should be able to generate a quote

  Background: Set up site and broker
    Given a CCA site exists with a benefit market
    Given there is a Broker XYZ Broking
    And the broker is assigned to a broker agency

  Scenario: Create quote for a Prospect Employer
    Given that a user with a Broker role exists and is logged in
    And the user is on the Add Prospect Employer Page
    When the user fills out and submits the Prospective Employer form
    And the user is on the Employers page of the Broker Portal
    And the user clicks Action for that Employer
    And the user clicks the ‘Create Quote’ option for a prospect employer
    And the user enters a quote name and selects a plan year effective date
    Then the user should see a success message confirming creation of the quote

  Scenario: Add employee to a quote roster
    Given that a user with a Broker role exists and is logged in
    And the broker has a prospect employer
    And the user is on the Employers page of the Broker Portal
    When the user clicks Action for that Employer
    And the user clicks the ‘Create Quote’ option for a prospect employer
    And the user enters a quote name and selects a plan year effective date
    And the user clicks the Add Employee button
    And the user fills out and submits the Add Employee form
    Then the user should see a success message confirming creation of the employee
    And the user should see a new record added to the roster

  Scenario: Setup Health Benefits By Carrier
    Given that carriers with proposal plans exist
    And that a user with a Broker role exists and is logged in
    And the broker has a prospect employer with a quote
    And prospect employer has an employee on the roster
    When the user is on the proposal plan selection page
    When the user selects Single Carrier
    And the user selects Harvard Pilgrim Health Care from the carrier selection list
    And the user selects 60% for the employee contribution
    And the user selects 50% for the spouse contribution
    And the user selects 50% for the domestic partner contribution
    And the user selects 50% for the child contribution
    And the user selects a reference plan
    Then the user should remain on the Select Health Benefits Page
    And the user should see a quote price
    And the user should see a new UI element labelled 'Health Plan Information'