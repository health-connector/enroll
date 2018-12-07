Feature: As a Super Admin I will be the only user
  that is able to see & access the "Extension of OE" Feature.

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    Given there is an employer ABC Widgets
    Given this employer has a canceled benefit application
    Given this benefit application has a benefit package containing health benefits

  Scenario: HBX Staff with HBX Tier 3 subroles should not see Extend OE button
    Given that a user with a HBX staff role with Super Admin subrole exists and is logged in
    Given the user is on the Employer Index of the Admin Dashboard
