Feature: Add Plan Year For Employer
  Scenario: Setup site, employer, and benefit market
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer with health benefits
    Given the user is on the Employer Registration page
    And Jack Doe create a new account for employer
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    When Employer try to create plan year with less than 33% contribution for spouse, domestic partner and child under 26
    Then Employer can not create plan year
    When ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    And ACME Widgets, Inc. should be able to set up benefit aplication
    And Employer should be able to enter plan year, benefits, relationship benefits for employer
    And Employer should see a success message after clicking on create plan year button

  Scenario: Add Deductible Display Shows on Plan Tile
    Given Add Deductible Display is Enabled
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer with health benefits
    Given the user is on the Employer Registration page
    And Jack Doe create a new account for employer
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    When Employer try to create plan year with less than 33% contribution for spouse, domestic partner and child under 26
    Then Employer can not create plan year
    When ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    And ACME Widgets, Inc. should be able to set up benefit aplication
    And Employer should be able to see deductible information of plans

  Scenario: Add Deductible Display Shows In View Summary
    Given Add Deductible Display is Enabled
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer with health benefits
    Given the user is on the Employer Registration page
    And Jack Doe create a new account for employer
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    When Employer try to create plan year with less than 33% contribution for spouse, domestic partner and child under 26
    Then Employer can not create plan year
    When ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    And ACME Widgets, Inc. should be able to set up benefit aplication
    And Employer clicks View Summary
    Then Employer should see deductible information in summary

   Scenario: Employer clicks Add Dental Benefit button
    Given Add Deductible Display is Enabled
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer that has both health and dental benefits
    Given the user is on the Employer Registration page
    And Jack Doe create a new account for employer
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    When Employer try to create plan year with less than 33% contribution for spouse, domestic partner and child under 26
    Then Employer can not create plan year
    When ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    And ACME Widgets, Inc. should be able to set up benefit aplication
    And Employer clicks Add Dental Benefit
    Then Employer should see dental benefits
