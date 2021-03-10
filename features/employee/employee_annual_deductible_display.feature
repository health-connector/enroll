Feature: Annual Deductible Display

  Scenario: Annual Deductible display on enrollment tile on employee home page
    Given Add Deductible Display is Enabled
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Qualifying life events are present
    And there is an employer ABC Widgets
    Given there exists Patrick Doe employee for employer ABC Widgets
    And initial employer ABC Widgets has active benefit application
    And employee Patrick Doe has past hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage in coverage enrolled state
    And Patrick Doe visits the employee portal
    And Patrick Doe should see annual deductible display
    And Employee logs out

  Scenario: Annual Deductible display on enrollment tile and plan comparison while shopping for plan
    Given Add Deductible Display is Enabled
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Qualifying life events are present
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has enrollment_open benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    And Patrick Doe has a matched employee role
    And Employee sees the Household Info: Family Members page and clicks Continue
    And Employee sees the Choose Coverage for your Household page and clicks Continue
    And Employee selects the first plan available
    And Employee clicks Confirm
    And Employee sees the Enrollment Submitted page and clicks Continue
    Then employee should see the enrollment with make changes button
    When employee clicked on make changes button
    When Employee clicks Shop for new plan button
    Then Patrick Doe should see the list of plans
    And Patrick Doe should see annual deductible display
    And Partick Doe selects plans to compare
    Then Patrick Doe should see medical and drug deductible information
    Then Partick Doe clicks on close button
    And Employee logs out
