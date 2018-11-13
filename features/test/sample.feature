Feature: As a broker/admin/POC
  I want to enroll in dental benefits offered by my employer
  So that I can get coverage for myself and my family

  Background: Setup benefit application with benefit package containing both health and dental sponsored benefits
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a draft benefit application
    And this benefit application has a benefit package containing health and dental benefits
    And at least one attestation document status is submitted

  Scenario: As an Employer publish benefit application with benefit package
    Given that a user with a Employer role exists and is logged in
    And the employee is on the Benefits page of the ABC Widgets employer portal
    When the user clicks 'Publish Plan Year'
    Then the benefit application should move to the enrolling state

  Scenario: As an Broker publish benefit application with benefit package
    Given that a user with a Broker role exists and is logged in
    And employer ABC Widgets has hired this broker
    And the broker is on the Benefits page of the ABC Widgets employer portal
