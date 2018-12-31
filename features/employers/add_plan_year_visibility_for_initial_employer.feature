Feature: As an Employer,
  when I am on the Benefits page of a given Employer
  then I should have the ability to creation a new benefit application.

  Background: Setup site, Employer, HBX staff, Broker, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets

    Scenario: No Plan Year Exists
    Given that a user with a Employer role exists and is logged in
    And this employer has a draft benefit application
    And this benefit application has a benefit package containing health benefits
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    When there are zero existing benefit applications
    Then the user will see an active Add Plan Year button.

    Scenario Outline: Existing Plan Year in <py_state> State
    Given that a user with a Employer role exists and is logged in
    And this employer has a <py_state> benefit application
    And this benefit application has a benefit package containing health benefits
    And the user is on the Employer Profile page for this employer
    When the user clicks the Benefits page link
    Then the user <will_or_will_not_see> an active Add Plan Year button.

    Examples:
      | py_state              | will_or_will_not_see  |
      | draft                 | will see              |
      | canceled              | will see              |
      | terminated            | will see              |
      | pending               | will not see          |
      | enrollment_ineligible | will not see          |
      | active                | will not see          |
