Feature: Add Plan Year For Employer
  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
  Scenario:
    Given the user is on the Employer Registration page
    And Jack Doe create a new account for employer
    And the user is registering a new Employer
    And all required fields have valid inputs on the Employer Registration Form
    And the user clicks the 'Confirm' button on the Employer Registration Form
    Then Employer visit the benefits page
    And Employer should see a button to create new plan year
    And ACME Widgets, Inc. should be able to set up benefit aplication, benefits, relationship benefits
    And Employer creates Benefit package

# Feature: Add Plan Year For Employer

#   Background: Setup site, employer, and benefit market
#     Given a CCA site exists with a benefit market
#     And there is an employer ABC Widgets
#     And ABC Widgets employer has a staff role
#     # And this employer has not setup a benefit application

#   Scenario: Add Plan year for Employer
#     Given staff role person logged in
#     Then ABC Widgets employer visit the benefits tab
#     And Employer should see a button to create new plan year
#     And ABC Widgets should be able to set up benefit aplication, benefits, relationship benefits
#     And Employer creates Benefit package


# Feature: Add Plan Year For Employer
#   Scenario: Add plan year for employer with horizontal and vertical choice
#     Given shop health plans exist for both last and this year
#     Given vertical and horizontal plan choices are offered
#     When I visit the Employer portal
#     Then Jack Doe create a new account for employer
#     And I select the all security question and give the answer
#     When I have submitted the security questions
#     Then I should see a successful sign up message
#     Then I should click on employer portal
#     Then Jack Doe creates a new employer profile with default_office_location
#     When I go to the Profile tab
#     When Employer goes to the benefits tab I should see plan year information
#     And Employer should see a button to create new plan year
#     When Employer try to create plan year with less than 33% contribution for spouse, domestic partner and child under 26
#     Then Employer can not create plan year
#     When I go to the Profile tab
#     When Employer goes to the benefits tab I should see plan year information
#     And Employer should see a button to create new plan year
#     And Employer should be able to enter plan year, benefits, relationship benefits for employer
#     And Employer should see a success message after clicking on create plan year button