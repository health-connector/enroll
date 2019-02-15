@wip
Feature: Passive renewal should be updated when EE updates his current coverage

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given Qualifying life events are present
    And there is an employer Acme Inc.
    And this employer has enrollment_open benefit application with offering health and dental
    And Acme Inc. employer has a staff role

  Scenario: Employee enters a SEP
    Given staff role person logged in
    And Acme Inc. employer visit the Employee Roster
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    When Patrick Doe creates an HBX account
    And I select the all security question and give the answer
    When I have submitted the security questions
    When Employee goes to register as an employee
    Then Employee should see the employee search page
    When Employee enters the identifying info of Patrick Doe
    Then Employee should see the matched employee record form
    When Employee accepts the matched employer
    When Employee completes the matched employee form for Patrick Doe
    And Employee sees the Household Info: Family Members page and clicks Continue
    And Employee sees the Choose Coverage for your Household page and clicks Continue
    And Employee selects the first plan available
    And Employee clicks Confirm
    And Employee sees the Enrollment Submitted page and clicks Continue

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
    Given Renewing Employer for Soren White exists with active and renewing plan year
      And Employee has past hired on date
      And Employer for Soren White is under open enrollment
      And Soren White already matched and logged into employee portal
      And Soren White has active coverage and passive renewal
      Then Soren White should see active and renewing enrollments
      When Soren White selects make changes on active enrollment
      Then Soren White should see page with SelectPlanToTerminate button
      When Soren White clicks SelectPlanToTerminate button
      Then Soren White selects active enrollment for termination
      When Soren White enters termination reason
      Then Soren White should see termination confirmation
      Then Soren White should see a waiver instead of passive renewal
