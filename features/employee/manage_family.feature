Feature: Employees can update their password or security questions

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    Given Continuous plan shopping is turned off
    And there is an employer Acme Inc.
    And Acme Inc. employer has a staff role

  Scenario: An employee can update their password with the correct original password
    Given Employer exists and logs in
    And employer Acme Inc. has enrollment_open benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
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
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick wife
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on the dependents page
    Then Employee should see the group selection page
    When Employee clicks continue button on group selection page for dependents
    Then Employee should see the list of plans
    And I should not see any plan which premium is 0
    When Employee selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee should see the receipt page
    Then Employee clicks on Continue button on receipt page
    Then Employee should see the "my account" page
    Then Employee should click on Manage Family button
    Then Employee should click on the Personal Tab link
    Then Employee should click on Change my Password link
    Then they can submit a new password
    And they should see a successful password message

  Scenario: An employee cannot update their password without the correct original password
    Given Employer exists and logs in
    And employer Acme Inc. has enrollment_open benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
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
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick wife
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on the dependents page
    Then Employee should see the group selection page
    When Employee clicks continue button on group selection page for dependents
    Then Employee should see the list of plans
    And I should not see any plan which premium is 0
    When Employee selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee should see the receipt page
    Then Employee should see the "my account" page
    Then Employee should click on Manage Family button
    Then Employee should click on the Personal Tab link
    Then Employee should click on Change my Password link
    Then Employee will submit with wrong password
    And they should see a password does not match error

  Scenario: An employee can update their security question responses
    Given Employer exists and logs in
    And employer Acme Inc. has enrollment_open benefit application
    And Acme Inc. employer visit the Employee Roster
    And there is a census employee record for Patrick Doe for employer Acme Inc.
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
    Then Employee should see the dependents page
    When Employee clicks Add Member
    Then Employee should see the new dependent form
    When Employee enters the dependent info of Patrick wife
    When Employee clicks confirm member
    Then Employee should see 1 dependents
    When Employee clicks continue on the dependents page
    Then Employee should see the group selection page
    When Employee clicks continue button on group selection page for dependents
    Then Employee should see the list of plans
    And I should not see any plan which premium is 0
    When Employee selects a plan on the plan shopping page
    When Employee clicks on Confirm button on the coverage summary page
    Then Employee should see the receipt page
    Then Employee should see the "my account" page
    Then Employee should click on Manage Family button
    Then Employee should click on the Personal Tab link
    Then Employee Soren White should click Update my security challenge responses
    When I select the all security question and give the answer
    When I have submitted the security questions
    Then I should see page redirected to Manage Family
  
