Feature: As an Employer,
  when I am on the Benefits page of a given Employer
  then I should have the ability to creation a new benefit application.

  Background: Setup site, Employer, HBX staff, Broker, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And this benefit application has a benefit package containing health benefits

    Scenario: No Plan Year Exists
    Given that a user with a Employer role exists and is logged in
    And this employer has a draft benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    When there are zero existing benefit applications
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Draft state
    Given that a user with a Employer role exists and is logged in
    And this employer has a draft benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Expired State
    Given that a user with a Employer role exists and is logged in
    And this employer has a expired benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Canceled State
    Given that a user with a Employer role exists and is logged in
    And this employer has a canceled benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Terminated State
    Given that a user with a Employer role exists and is logged in
    And this employer has a terminated benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will see an active Add Plan Year button.

    Scenario: Existing Plan Year in Publish Pending State
    Given that a user with a Employer role exists and is logged in
    And this employer has a terminated benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.

    Scenario: Existing Plan Year in Enrolling State
    Given that a user with a Employer role exists and is logged in
    And this employer has a enrolling benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.

    Scenario: Existing Plan Year in Enrollment Closed State
    Given that a user with a Employer role exists and is logged in
    And this employer has a enrollment closed benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.

    Scenario: Existing Plan Year in Enrolled State
    Given that a user with a Employer role exists and is logged in
    And this employer has a enrolled benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.

    Scenario: Existing Plan Year in Enrollment Ineligible State
    Given that a user with a Employer role exists and is logged in
    And this employer has a enrolled benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.

    Scenario: Existing Plan Year in Active State
    Given that a user with a Employer role exists and is logged in
    And this employer has a active benefit application
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user will not see an active Add Plan Year button.



