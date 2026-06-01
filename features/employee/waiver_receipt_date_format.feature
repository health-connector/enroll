Feature: Waiver receipt date format

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    Given Continuous plan shopping is turned off
    And there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    And initial employer Acme Inc. has enrollment_open benefit application

  Scenario: Waiver receipt shows date in MM/DD/YYYY format
    Given there exists Patrick Doe employee for employer Acme Inc.
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer Acme Inc. and logged into employee portal
    When Employee clicks "Shop for Plans" on my account page
    Then Employee should see the group selection page
    When Employee clicks continue on the group selection page
    Then Employee should see the list of plans
    When Employee selects waiver on the plan shopping page
    When Employee submits waiver reason
    Then Employee should see waiver summary page
    When Employee clicks continue on waiver summary page
    Then the waiver receipt should show the waived date formatted as MM/DD/YYYY
