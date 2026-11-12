Feature: Employee self-registration when an unrelated person shares their name and DOB
  An employee who already exists in the system with their SSN on file (for example, as a
  spouse on another employee's family) must be able to register their own employee account,
  even when an unrelated person with the same name and date of birth, but no SSN on file,
  also exists. The SSN-verified record should be used instead of blocking registration.

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    And there is an employer Acme Inc.
    And Acme Inc. employer has a staff role
    And employer Acme Inc. has enrollment_open benefit application
    And there is a census employee record for Patrick Doe for employer Acme Inc.

  Scenario: Employee with an existing SSN-verified record and a name/DOB collision registers successfully
    Given Continuous plan shopping is turned off
    And Patrick Doe exists with an SSN as a spouse on another employee's family
    And an unrelated person named Patrick Doe with the same DOB and no SSN exists
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
    Then Employee should not see the enroll as another employee error
    When Employee completes the matched employee form for Patrick Doe
    Then Employee should see the dependents page
    And the employee role for Patrick Doe should belong to the SSN-verified person
    And the unrelated Patrick Doe record without an SSN should be unchanged
