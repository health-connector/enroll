Feature: As an admin user I should have the ability to click revise end date button on Employer datatable
  
    Scenario Outline: Admin clicks reinstate button under plan year dropdown for <aasm_state> benefit_application
    Given the Revise End Date feature configuration is enabled
    And a CCA site exists with a benefit market
    And benefit market catalog exists for <from_state> initial employer with health benefits
    And there is an employer ABC Widgets
    And initial employer ABC Widgets has <from_state> benefit application
    And initial employer ABC Widgets application <to_state>
    And that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Plan Years button
    Then the user will select benefit application to revise end date
    When the user clicks Actions for that benefit application
    Then the user will see Revise End Date button
    When Admin clicks on Revise End Date button
    Then Admin will set Revise End Date in <revise_date> for <to_state> benefit application
    And Admin will see transmit to carrier checkbox
    When Admin clicks on Submit button
    Then Admin will see Revise End Date confirmation pop up modal
    And Admin clicks on continue button for revise_end_date benefit application
    And user logs out

  Examples:
    |  from_state |    to_state          | revise_date |
    |   active    |   terminated         | past        |
    |   active    |   terminated         | future      |
    |   active    | termination_pending  | past        |
    |   active    | termination_pending  | future      |
