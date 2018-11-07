Feature: As a broker/admin/POC
  I want to enroll in dental benefits offered by my employer
  So that I can get coverage for myself and my family

  Background: Setup benefit application with benefit package containing both health and dental sponsored benefits
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has a draft benefit application
