Feature: Visit Issuer page

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    And Admin_issuers_tab_display is on

  Scenario: HBX Staff with Super Admin subroles should see Change FEIN button
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Issuers Index of the Admin Dashboard
    And the user will see Marketplaces table
    Then the user will see correct content in table