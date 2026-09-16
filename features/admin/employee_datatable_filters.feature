Feature: Admin using Employee Datatable Filters

  Scenario: Admin filtering employees by Enrolled coverage
    Given Add Deductible Display is Enabled
    And a CCA site exists with a benefit market
    And benefit market catalog exists for enrollment_open renewal employer with health benefits
    And Qualifying life events are present
    And there is an employer ABC Widgets
    And there exists Patrick Doe employee for employer ABC Widgets
    And initial employer ABC Widgets has active benefit application
    And employee Patrick Doe has past hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage in coverage enrolled state
    And Employee logs out
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Employees Index of the Admin Dashboard
    And the admin filters employees by Enrolled coverage
    Then the admin should see Patrick Doe in the datatable

  Scenario: Admin filtering employees by Renewing coverage
    Given a CCA site exists with a benefit market
    And benefit market catalog exists for enrollment_open renewal employer with health benefits
    And Continuous plan shopping is turned off
    And there is an employer ABC Widgets
    And employer ABC Widgets has active and renewing enrollment_open benefit applications
    And this employer ABC Widgets has first_of_month_after_30_days rule
    And this employer renewal application is under open enrollment
    And there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has past hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage and passive renewal
    And Employee logs out
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Employees Index of the Admin Dashboard
    And the admin filters employees by Renewing coverage
    Then the admin should see Patrick Doe in the datatable

  Scenario: Admin filtering employees by Waived coverage
    Given a CCA site exists with a benefit market
    And benefit market catalog exists for enrollment_open renewal employer with health benefits
    And Continuous plan shopping is turned off
    And there is an employer ABC Widgets
    And employer ABC Widgets has active and renewing enrollment_open benefit applications
    And this employer offering 0.75 contribution to Employee
    And this employer ABC Widgets has first_of_month rule
    And there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    When Employee clicks "Shop for Plans" on my account page
    And Employee clicks continue on the group selection page
    And Employee selects waiver on the plan shopping page
    And Employee submits waiver reason
    And Employee clicks continue on waiver summary page
    And Employee logs out
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Employees Index of the Admin Dashboard
    And the admin filters employees by Waived coverage
    Then the admin should see Patrick Doe in the datatable

  Scenario: Admin filtering employees by SEP eligible
    Given Add Deductible Display is Enabled
    And a CCA site exists with a benefit market
    And benefit market catalog exists for enrollment_open renewal employer with health benefits
    And Qualifying life events are present
    And there is an employer ABC Widgets
    And there exists Patrick Doe employee for employer ABC Widgets
    And initial employer ABC Widgets has active benefit application
    And employee Patrick Doe has past hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage in coverage enrolled state
    And Employee logs out
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And Patrick Doe has an active SEP
    And the user is on the Employees Index of the Admin Dashboard
    And the admin filters employees by SEP eligible coverage
    Then the admin should see Patrick Doe in the datatable
