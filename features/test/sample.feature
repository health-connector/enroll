Feature: As a broker/admin/POC
  I want to enroll in dental benefits offered by my employer
  So that I can get coverage for myself and my family
  
  Background: Setup benefit application with benefit package containing both health and dental sponsored benefits
    Given a CCA site exists with a health benefit market
    And there is an employer ABC Widgets
    And this employer has a draft benefit application
    And this benefit application has a benefit package containing both health and dental benefits
    And at least one attestation document status is submitted
  
    Scenario: Publish benefit application with benefit package as POC
    Given that a user with an Employer role exists and is logged in
    And the employee is on the Benefits page of the ABC Widgets employer portal
    