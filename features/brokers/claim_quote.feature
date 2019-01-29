Feature: Claim Quote
  In order for Employers to be able to create a plan year from quote information
  The Employer should be able to claim a quote

   Background:
     Given a CCA site exists with a benefit market
     Given there is a Broker XYZ
     Given there is an employer ABC Widgets
     And the broker is assigned to a broker agency
     And employer ABC Widgets has hired this broker
     
  Scenario: Claim a valid quote
    Given XYZ Broking has a valid quote for ABC Widgets
    Given ABC Widgets does not have a benefit application
    Given that a user with a Employer role exists and is logged in
    And the user is on the Benefits page for ABC Widgets
    When the user clicks the Claim Quote button
    And the user clicks Proceed
    And the user enters a valid claim code
    And the user clicks Claim Code
    Then the employer should see a successful message
    And the employer should see a plan year in draft state

  Scenario: Claim a valid quote for a renewal plan year
    Given XYZ Broking has a valid quote for ABC Widgets
    Given ABC Widgets has an renewing draft benefit application
    And that a user exists with Employer role and is logged in
    And the user is on the Benefits page for ABC Widgets
    When the user clicks the Claim Quote button
    And the user clicks Proceed
    And the user enters a valid claim code
    And the user clicks Claim Code
    Then the employer should see a successful message
    And the employer should see a renewal plan year in draft state

  Scenario: Attempt to claim an invalid quote claim code
    Given XYZ Broking has a valid quote for ABC Widgets
    Given ABC Widgets does not have a benefit application
    And that a user exists with Employer role and is logged in
    And the user is on the Benefits page for ABC Widgets
    When the user clicks the Claim Quote button
    And the user clicks Proceed
    And the user enters an invalid claim code
    And the user clicks Claim Code
    Then the employer should see an error message