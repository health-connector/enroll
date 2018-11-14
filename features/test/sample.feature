Feature: As a broker/admin/POC
  I want to enroll in dental benefits offered by my employer
  So that I can get coverage for myself and my family

  Background: Setup benefit application with benefit package containing both health and dental sponsored benefits
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a draft benefit application
    And this benefit application has a benefit package containing health and dental benefits

  Scenario: As an POC publish benefit application with benefit package
    Given that a user with a Employer role exists and is logged in
    And the POC is on the Benefits page of the ABC Widgets employer portal
    When the POC clicks 'Publish Plan Year'
    Then the benefit application should move to the enrolling state

  Scenario: As an Broker publish benefit application with benefit package
    Given employer ABC Widgets has hired this broker
    Given that a user with a Broker role exists and is logged in
    And the broker is on the Benefits page of the ABC Widgets employer portal
    When the broker clicks 'Publish Plan Year'
    Then the benefit application should move to the enrolling state
