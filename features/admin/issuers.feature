Feature: Visit Issuer and nested pages

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market and exempt organization
    Given benefit market catalog exists for enrollment_open initial employer with health benefits
    Given that a user with a HBX staff role with HBX staff subrole exists and is logged in
    Given products marked as premium value products
    And Admin_issuers_tab_display is on

  Scenario: HBX Staff with Super Admin subroles should see Marketplace page
    And the user is on the Issuers Index of the Admin Dashboard
    And the user will see Marketplaces table
    Then the user will see correct content in table

  Scenario: HBX Staff with Super Admin subroles should see Marketplace Plan Year Index page
    And the user is on the Issuers Index of the Admin Dashboard
    Then the user visit the Marketplace Plan Year Index page
    And the user will see Marketplace Plan Year Index table
    Then the table should have "current_year" in the "Year" column
    Then the table should have "5" in the "Plans" column
    Then the table should have "1" in the "PVP Marking(s)" column
    Then the table should have "0" in the "Enrollments" column
    Then the table should have "Health" in the "Products" column

  Scenario: HBX Staff with Super Admin subroles should see Marketplace Carriers page
    And the user is on the Issuers Index of the Admin Dashboard
    And the user visit the Marketplace Plan Year Index page
    Then the user visit the Marketplace Carriers page
    And the user will see Marketplace Carriers table
    Then the table should have "Health Agency Authority" in the "Carrier" column
    Then the table should have "2" in the "Plans" column
    Then the table should have "2" in the "PVP Marking(s)" column
    Then the table should have "0" in the "Enrollments" column
    Then the table should have "Health, Dental" in the "Products" column

  Scenario: HBX Staff with Super Admin subroles should see Marketplace Carrier page
    And the user is on the Issuers Index of the Admin Dashboard
    And the user visit the Marketplace Plan Year Index page
    Then the user visit the Marketplace Carriers page
    And the user visit the Marketplace Carrier page
    Then the table should have "BlueChoice bronze 2,000" in the "Plan name" column
    Then the table should have "POS" in the "Plan type" column
    Then the table should have "1" in the "PVP rating areas" column
    Then the table should have "Gold" in the "Metal level" column
    And check the "Plan type" filter "POS"
    And click on "Apply Filters"
    Then should see plans with the following:
      | Plan Type | POS |
    And check the "PVP rating areas" filter "R-MA001"
    And click on "Apply Filters"
    Then should see plans with the following:
      | PVP areas | 1 |
    And click on "Clear Filters"
    And check the "Metal level" filter "Gold"
    And click on "Apply Filters"
    Then should see plans with the following:
      | Metal level | Gold |
    And click on "Clear Filters"
    And search for "bronze"
    And click on "Search"
    Then should see plans with the following:
      | Plan name | bronze |

  Scenario: HBX Staff with Super Admin subroles should see Detail Plan Page
    Given all products has correct qhps
    And the user visit the Detail Plan page
    Then the user should see Plan title
    Then the user should see Plan benefit type
    Then the user should see Plan metal tier
    Then the user should see Plan PVP areas
    Then the user should see HIOS id
    Then the user should see Availability table
    Then the user should see Estimated Cost table
