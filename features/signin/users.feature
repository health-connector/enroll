Feature: Signin into user account
  I want to signin as a returning user
  
  Scenario: Successfully sign in as a user
    Given I am a valid user
    When I complete the Sign In form
    Then I should see the welcome page
