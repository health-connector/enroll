Feature: EE plan purchase

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Continuous plan shopping is turned off
    Given Qualifying life events are present

  Scenario: when EE purchase plan for self
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
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
    When Employee click the "Married" in qle carousel
    And Employee select a past qle date
    Then Employee should see confirmation and clicks continue
    Then Employee should see the dependents page
    When Employee clicks continue on group selection page for dependents
    When Employee clicks Shop for new plan button
    Then Patrick Doe should see the list of plans
    When Patrick Doe selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee clicks back to my account button
    Then Patrick Doe should see primary person
    And Employee logs out

  Scenario: when EE purchase plan for self & dependent
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
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
    And Employee logs out

  Scenario: EE having an ineligible family member & doing plan shop
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
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
    When Employee click the "Married" in qle carousel
    And Employee select a past qle date
    Then Employee should see confirmation and clicks continue
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick daughter
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on group selection page for dependents
    And employee should see the ineligible family member disabled and unchecked
    And employee should see the eligible family member enabled and checked
    And Patrick Doe should also see the reason for ineligibility
    When Employee clicks Shop for new plan button
    Then Patrick Doe should see the list of plans
    When Patrick Doe selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee clicks back to my account button
    Then Patrick Doe should see primary person
    And Employee logs out

  Scenario: EE plan shopping by clicking on 'make changes' button on enrollment
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
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
    When Patrick Doe selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    And Employee sees the Enrollment Submitted page and clicks Continue
    Then Patrick Doe should see primary person
    And Employee logs out

  Scenario: EE having an ineligible family member & doing plan shop for renewals
    Then there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And employer ABC Widgets has active and renewing enrollment_open benefit applications
    And this employer renewal application is under open enrollment
    And there is a census employee record for Patrick Doe for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    And Patrick Doe has active coverage and passive renewal
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
    When Employee enters the dependent info of Patrick daughter
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on group selection page for dependents
    And employee should see the ineligible family member disabled and unchecked
    And employee should see the eligible family member enabled and checked
    And Patrick Doe should also see the reason for ineligibility
    When Employee clicks Shop for new plan button
    Then Patrick Doe should see the list of plans
    When Patrick Doe selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee clicks back to my account button
    Then Patrick Doe should see primary person
    And Employee logs out

  Scenario: EE having an ineligible family member & doing continuous plan shop
    Given Continuous plan shopping is enabled
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    And Patrick Doe has a matched employee role
    And Employee sees the Household Info: Family Members page and clicks Continue
    Then Employee should not see the ineligible for dental coverage message if dental is not offered
    And Employee sees the Choose Coverage for your Household page and clicks Confirm your Selections button
    And Employee selects the first plan available
    And Employee clicks Confirm
    And Employee sees the Enrollment Submitted page and clicks Continue
    When Employee click the "Married" in qle carousel
    And Employee select a past qle date
    Then Employee should see confirmation and clicks continue
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick daughter
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on group selection page for dependents
    Then Employee should not see the ineligible for dental coverage message if dental is not offered
    Then Employee should see the ineligible for health coverage message

  Scenario: EE sees product filters while continuous plan shopping
    Given Continuous plan shopping is enabled
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    And Patrick Doe has a matched employee role
    And Employee sees the Household Info: Family Members page and clicks Continue
    Then Employee should not see the ineligible for dental coverage message if dental is not offered
    And Employee sees the Choose Coverage for your Household page and clicks Confirm your Selections button
    # Start Filter Tests
    Then the Employee will see a Metal Level Filter
    And the Employee will have the ability to filter plans by metal level
    Then the Employee will see a Plan Type Filter
    Then the employee will see standard plan and pvp filters
    And the Employee will have the ability to filter plans by plan type
    Then the Employee will see a Carrier dropdown
    And the Employee will have the ability to view plans by carrier
    Then the Employee will see a HSA Eligible dropdown
    And the Employee will have the ability to view plans by HSA eligibility
    Then the Employee will see premium amount fields
    And the Employee will have the ability to enter a premium amount number range
    Then the Employee will see deductible amount fields
    And the Employee will have the ability to enter a deductible amount number range

  Scenario: EE should not see pvp filter when feature is disabled
    Given Continuous plan shopping is enabled
    Given premium value plans feature is disabled
    Given there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    When staff role person logged in
    And employer Acme Inc. has active benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    And Patrick Doe has a matched employee role
    And Employee sees the Household Info: Family Members page and clicks Continue
    Then Employee should not see the ineligible for dental coverage message if dental is not offered
    And Employee sees the Choose Coverage for your Household page and clicks Confirm your Selections button
    Then the Employee will see a Plan Type Filter
    Then the employee will not see standard plan and pvp filters