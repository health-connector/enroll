Feature: PVP and standard plan indicators should be displayed 
  When Broker creates a quote for a prospect employer

  Background: Set up employer, broker and their relationship
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Continuous plan shopping is turned off
    And the Plans exist
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And renewal employer ABC Widgets has active and renewal enrollment_open benefit applications
    And this employer renewal application is under open enrollment
    And there is a Broker Agency exists for District Brokers Inc
    And the broker Max Planck is primary broker for District Brokers Inc
    And employer ABC Widgets hired broker Max Planck from District Brokers Inc

  Scenario: Broker should see pvp filter when premium_value_products feature enabled
    Given Max Planck logs on to the Broker Agency Portal
    When the broker clicks on Employers tab
    When the broker clicks Actions for that Employer
    Then the broker sees Create Quote button
    Then the broker clicks on Create Quote button
    And the broker sees quote for ABC Widgets employer
    And the broker clicks on Back to Employer Index button
    Then the broker should see the Effective Date formatted