Feature: I want to register an Employer on the Enroll Application

  Background: Setup site, HBX Staff logged in, on Employer Registration Page
    Given a CCA site exists with a benefit market
    And the user is on the root index page
    And the user click the Employer Portal link
    And the user has successfully signed up

  Scenario: Successfully complete and submit the Employer Registration Form
    Given all required fields have valid inputs on the Employer Registration Form 
