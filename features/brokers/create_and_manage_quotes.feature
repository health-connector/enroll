Feature: Create and Manage Quotes
  In order for Brokers to be able to send a quote to an employe to claim
  The broker should be able to generate a quote

  Background: Set up site and broker
    Given a CCA site exists with a benefit market
    Given there is a Broker XYZ Broking
    And the person is assigned to a broker agency

  Scenario: Create quote for a Prospect Employer
    Given that a user with a Broker role exists and is logged in
    And the user is on the Add Prospect Employer Page
    When the user fills out and submits the Prospective Employer form
    And the user is on the Employers page of the Broker Portal
    When the user clicks Action for that Employer
    When the user clicks the ‘Create Quote’ option for a prospect employer
    When the user enters a quote name and selects a plan year effective date
    Then the user should see a success message confirming creation of the quote