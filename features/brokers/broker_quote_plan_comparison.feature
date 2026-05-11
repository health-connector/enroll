Feature: Broker creates a quote for a prospect employer and compares plans
  When employer_broker_ui_enhancements feature is enabled
  Broker should see the plan comparisons table displayed as a modal

  Background: Set up employer, broker and their relationship
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer with health benefits
    And all products has correct qhps
    Given Continuous plan shopping is turned off
    And the Plans exist
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And initial employer ABC Widgets has enrollment_open benefit application
    And there is a Broker Agency exists for District Brokers Inc
    And the broker Max Planck is primary broker for District Brokers Inc
    And employer ABC Widgets hired broker Max Planck from District Brokers Inc

  Scenario Outline: Broker should see plan comparison displayed as a modal
    Given employer_broker_ui_enhancements feature is enabled
    And Max Planck logs on to the Broker Agency Portal
    And the broker clicks on Employers tab
    And the broker clicks Actions for that Employer
    And the broker clicks on Create Quote button
    And Primary Broker enters quote name
    And the broker clicks on Select Health Benefits button
    And the broker selects plan offerings by metal level and enters <contribution_pct> for employee and deps
    And broker selects plans for comparison
    Then broker should see plan comparison modal
    Then broker closes the plan comparison modal
    And broker clears selections and selects new plans for comparison
    Then broker should see plan comparison modal

    Examples:
      | contribution_pct |
      | 50               |