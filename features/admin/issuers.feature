Feature: Visit Issuer page

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    And Admin_issuers_tab_display is on

  Scenario: HBX Staff with Super Admin subroles should see Marketplace page
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Issuers Index of the Admin Dashboard
    And the user will see Marketplaces table
    Then the user will see correct content in table

  Scenario: HBX Staff with Super Admin subroles should see Marketplace Plan Year Index page
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Issuers Index of the Admin Dashboard
    Then the user visit the Marketplace Plan Year Index page
    And the user will see Marketplace Plan Year Index table
    Then the table should have "2024" in the "Year" column
    Then the table should have "5" in the "Plans" column
    Then the table should have "0" in the "PVP Plans" column
    Then the table should have "0" in the "Enrollments" column
    Then the table should have "Health" in the "Products" column

  Scenario: HBX Staff with Super Admin subroles should see Marketplace Carrier page
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    And the user is on the Issuers Index of the Admin Dashboard
    And the user visit the Marketplace Plan Year Index page
    Then the user visit the Marketplace Carrier page
    And the user will see Marketplace Carrier table