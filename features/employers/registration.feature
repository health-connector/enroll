Feature: I want to register an Employer on the Enroll Application

  Background: Setup site, HBX Staff logged in, on Employer Registration Page
    Given a CCA site exists with a benefit market
    Given that a user with a HBX staff role with HBX Staff subrole exists and is logged in
    And the user is on the Employer Registration page
    And the user is registering a new Employer

  Scenario: I have Successful Submission
    Given all required fields have valid inputs on the Employer Registration Form
    When the user clicks the 'Confirm' button on the Employer Registration Form
