Feature: Broker adds a prospect employer and uses SIC code helper
  In order for Brokers to add a prospect employer with a SIC code
  The Broker should be able to click the SIC code question mark
  And see the SIC code helper panel with search functionality

  Background: Set up broker and broker agency
    Given a CCA site exists with a benefit market
    And there is a Broker Agency exists for District Brokers Inc
    And the broker Max Planck is primary broker for District Brokers Inc

  Scenario: Broker clicks SIC code question mark on Add Prospect Employer form and sees SIC helper
    Given Max Planck logs on to the Broker Agency Portal
    When the broker visits the prospect employer new page for District Brokers Inc
    Then the broker should see the Add Prospect Employer form
    And the broker should see the SIC code question mark link
    When the broker clicks on the SIC code question mark
    Then the broker should see the SIC code helper panel
    And the broker should see the SIC code search input

  Scenario: Broker clicks SIC code question mark and toggles the SIC helper panel closed
    Given Max Planck logs on to the Broker Agency Portal
    When the broker visits the prospect employer new page for District Brokers Inc
    Then the broker should see the Add Prospect Employer form
    When the broker clicks on the SIC code question mark
    Then the broker should see the SIC code helper panel
    When the broker clicks on the SIC code question mark
    Then the broker should not see the SIC code helper panel
