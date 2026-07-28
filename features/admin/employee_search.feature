Feature: Employee passive renewal should be canceled when Employee selected coverage

  After a passive renewal if employee makes a plan selection, passive renewal should be canceled

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Continuous plan shopping is turned off
    And there is an employer ABC Widgets
    And employer ABC Widgets has active and renewing enrollment_open benefit applications
    And this employer ABC Widgets has first_of_month_after_30_days rule
    And this employer renewal application is under open enrollment

  Scenario: Search for employee and verify only one deductible tooltip is visible on the page
    Given there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has past hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage and passive renewal
    Then Patrick Doe should see active and renewing enrollments
    And only one deductible tooltip should be visible on the page
    And Employee logs out
    When that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Employees Index of the Admin Dashboard
    And the user searches for the employee Patrick Doe
    And only one deductible tooltip should be visible on the page

