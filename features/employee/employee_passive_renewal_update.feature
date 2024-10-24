Feature: Passive renewal should be updated when EE updates his current coverage

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Continuous plan shopping is turned off
    Given Qualifying life events are present
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And employer ABC Widgets has active and renewing enrollment_open benefit applications
    And this employer renewal application is under open enrollment

  Scenario: Employee enters a SEP
    Given there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage and passive renewal
    # Then Patrick Doe should see active and renewing enrollments
    When Patrick Doe clicks "Shop for Plans" on my account page
    Then Employee should see the group selection page
    When Employee clicks continue on the group selection page
    Then Employee should see the list of plans
    When Employee selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee should see the receipt page
    Then Employee should see the "my account" page

    When Employee click the "Married" in qle carousel
    And Employee select a past qle date
    Then Employee should see confirmation and clicks continue
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick wife
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on group selection page for dependents
    When Employee clicks Shop for new plan button
    Then Patrick Doe should see the list of plans
    When Patrick Doe selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee clicks back to my account button
    Then Patrick Doe should see active enrollment with their spouse

  Scenario: Passively Renewed Employee terminates his coverage
    Given there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage and passive renewal
    Then Patrick Doe should see active and renewing enrollments
    When Patrick Doe selects make changes on active enrollment
    Then Patrick Doe should see page with SelectPlanToTerminate button
    When Patrick Doe clicks SelectPlanToTerminate button
    When Patrick Doe submits termination reason in modal
    Then Patrick Doe should see a confirmation message of Waive Coverage Successful
