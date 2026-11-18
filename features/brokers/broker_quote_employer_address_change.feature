Feature: Broker quote uses the employer's current address
  When an employer changes its primary office address in Business Info
  The broker's quotes for that employer should use the new zip code and county

  Background: Set up employer, broker and their relationship
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open renewal employer with health benefits
    Given Continuous plan shopping is turned off
    And the Plans exist
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And renewal employer ABC Widgets has active and renewal enrollment_open benefit applications
    And this employer renewal application is under open enrollment
    And there is a Broker Agency exists for District Brokers Inc
    And the broker Max Planck is primary broker for District Brokers Inc
    And employer ABC Widgets hired broker Max Planck from District Brokers Inc

  Scenario: Broker quote shows the zip code and county the employer changed to
    Given zip code 01060 is in Hampshire county
    And staff role person logged in
    And ABC Widgets is logged in and on the home page
    When the employer decides to Update Business information
    And the employer changes the primary office zip code to 01060 in Hampshire county and clicks on save
    Then the employer should see the Employer successfully Updated message
    And the employer logs out
    When Max Planck logs on to the Broker Agency Portal
    And the broker clicks on Employers tab
    And the broker clicks Actions for that Employer
    And the broker clicks on Create Quote button
    Then the broker sees quote for ABC Widgets employer
    And the broker sees zip code 01060 and county Hampshire on the quote
