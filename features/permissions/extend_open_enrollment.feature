Feature: As a Super Admin I will be the only user
  that is able to see & access the "Extension of Open Enrollment" Feature.

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given there is an employer ABC Widgets
    Given this employer has a enrolling benefit application
    Given this benefit application has a benefit package containing health benefits

  Scenario: HBX Staff with Super Admin subroles should see Extend Open Enrollment button
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will see the Extend Open Enrollment button

  Scenario: HBX Staff with HBX Staff subroles should not see Extend Open Enrollment button
    Given that a user with a HBX staff role with HBX Staff subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will not see the Extend Open Enrollment button

  Scenario: HBX Staff with HBX Read Only subroles should not see Extend Open Enrollment button
    Given that a user with a HBX staff role with HBX Read Only subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will not see the Extend Open Enrollment button

  Scenario: HBX Staff with Developer subroles should not see Extend Open Enrollment button
    Given that a user with a HBX staff role with Developer subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will not see the Extend Open Enrollment button

  Scenario: HBX Staff with HBX Tier3 subroles should not see Extend Open Enrollment button
    Given that a user with a HBX staff role with HBX Tier3 subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
    When the user clicks Action for that Employer
    Then the user will not see the Extend Open Enrollment button
