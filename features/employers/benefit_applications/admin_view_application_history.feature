Feature: As an admin user I should have the ability to click application history button on Employer datatable
  
    Scenario Outline: Admin clicks application history button under plan year dropdown for <aasm_state> benefit_application
    And a CCA site exists with a benefit market
    And benefit market catalog exists for <from_state> initial employer with health benefits
    And there is an employer ABC Widgets
    And initial employer ABC Widgets has <from_state> benefit application
    And that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Plan Years button
    Then the user will select benefit application to view_history
    When the user clicks Actions for that benefit application
    Then the user will see application history button
    When Admin clicks on application history button
    Then Admin will see application history page
    Then admin will see option to click return to employer index view
    When admin clicks on return to employer index view link
    Then admin will go to employer index page
    And user logs out

  Examples:
    |  from_state   |
    |   draft       |
    |   active      |
    |   terminated  |
