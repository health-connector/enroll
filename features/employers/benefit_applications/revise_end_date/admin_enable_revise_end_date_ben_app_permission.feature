Feature: As an admin user I should have the ability to <action> revise end date button on Employer datatable with revise end date feature <feature_switch> with resource registry

  Scenario Outline: Setup site, employer, and benefit application
    Given the Revise End Date feature configuration is <feature_switch>
    And a CCA site exists with a benefit market
    And benefit market catalog exists for active initial employer with health benefits
    And there is an employer ABC Widgets
    And initial employer ABC Widgets has <aasm_state> benefit application
    And that a user with a HBX staff role with Super Admin subrole exists and is logged in
    And the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Plan Years button
    Then the user will select benefit application to revise end date
    When the user clicks Actions for that benefit application
    Then the user will <action> Revise End Date button
    And user logs out

  Examples:
    | feature_switch |    aasm_state       | action  |
    |    enabled     |    terminated       | see     |
    |    enabled     | termination_pending | see     |
    |    disabled    |      active         | not see |
    |    disabled    |    terminated       | not see |

