Feature: As and Employer,
  when I am on the Benefits page of a given Employer
  then I should have the ability to creation a new benefit application.

  Background: Setup site, Employer, HBX staff, Broker, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this benefit application has a benefit package containing health benefits
    Given that a user with a Employer role exists and is logged in

    Scenario: No Plan Year Exists
    And this employer has a draft benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    When there are zero existing benefit applications
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Draft state
    And this employer has a draft benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Expired State
    And this employer has a expired benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Canceled State
    And this employer has a canceled benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Terminated State
    And this employer has a terminated benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.
