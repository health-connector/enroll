Feature: Employer should be able to view payment details

  Background: Setup site, employer
    Given a DC site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    And an employer ABC Widgets exists with statements and premium payments
    And ABC Widgets employer has a staff role
    And staff role person logged in

  Scenario: An Employer should be able to view payment history
    When ABC Widgets is logged in and on the home page
    And the employer decides to Update Business information
    And the employer adds a mailing address and clicks on save
    Then the employer should see the Employer successfully Updated message