Feature: I want to create a Benefit Application for my employer profile

  Background: Setup site, Navigate to Root Index page, Signup as user
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this employer has not setup a benefit application

  Scenario: Create a Benefit Application for Employer
    Given that a user with a Employer role exists and is logged in
    And the user is on the Employer Benefits homepage
    When the user clicks the Add Plan Year button
    Then the user will see the Add Benefit Package page
    When the user completely fills out the Benefit Package form
    Then the user will be able to submit the Benefit Package
