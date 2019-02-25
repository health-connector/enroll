Feature: I want to register as an Employer on the Enroll Application

  Background: Setup site, Navigate to Root Index page, Signup as user
    Given a CCA site exists with a benefit market
    And the user is on the root index page
    And the user clicks the Employer Portal link
    And the user has successfully signed up

  Scenario: Successfully complete and submit the Employer Registration Form
    Given all required fields have valid inputs on the Employer Registration Form
    When the user clicks the 'Confirm' button on the Employer Registration Form
    Then the user will navigate to a new page "My Health Benefits Program"

  Scenario: Required Data is missing from the Employer Registration Form
    Given at least one required field is blank on the Employer Registration Form
    When the user clicks the 'Confirm' button on the Employer Registration Form
    Then the user will be prompted to enter missing information from the Employer Registration Form
