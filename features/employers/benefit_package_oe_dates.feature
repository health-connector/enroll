Feature: Add Plan Year For Employer
  Scenario: Setup site, employer, and benefit market
    Given a CCA site exists with a benefit market
    Given SAFE benefit market catalog exists for enrollment_open initial employer with health benefits
    Given the user is on the Employer Registration page
    Given Security questions exist
    And Jack Doe create a new account for employer
    When the user fills out the security questions modal
    When the user submitted the security questions
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then ACME Widgets, Inc. Employer visit the benefits page
    And Employer should see a button to create new plan year
    And Employer selects a plan year start date
    When employer clicks on the open enrollment start date field
    Then employer should see the datepicker calendar
    And retroactive dates should be disabled in the datepicker