Feature: Orphan Accounts tab
  Background: Setup permissions and other things
    Given all permissions are present

  Scenario: hbx admin logged in and orphan accounts tab is enabled
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And I click HBX portal
    And the user visits the orphan accounts page
    Then the user should see the orphan accounts page

  Scenario: user without permissions attempts to visit the orphan accounts page
    Given a consumer exists
    And the consumer is logged in
    When the user navigates directly to the orphan accounts page
    Then the user should not see the orphan accounts page
