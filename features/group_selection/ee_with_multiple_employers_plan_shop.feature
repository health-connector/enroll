Feature: EE with multiple employers plan purchase

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And there is an employer DEF Sales
    And employer ABC Widgets has active benefit application
    And employer DEF Sales has active benefit application
    Then person has multiple employee roles with benefits from employers ABC Widgets and DEF Sales

  Scenario: when EE purchase plan for self & having ineligible family member - 
    ER1 ABC Widgets - Health & dental benefits - not offers dental benefits to spouse
    ER2 DEF Sales - Only Health benefits - not offers to spouse
    Employee - John

    Given ABC Widgets ER does not offer dental benefits to spouse
    And DEF Sales ER does not offer health benefits to spouse
    When employee has a valid "Married" qle
    And John sign in to portal
    And employee John with a dependent has spouse relationship with age less than 26
    When Employee click the "Married" in qle carousel
    And Employee select a past qle date
    And Employee should see confirmation and clicks continue
    When employee clicked continue on household info page
    And employee should see all the family members names
    # And employee should see the dental radio button
    # And employee should not see the reason for ineligibility
    # And employee switched to dental benefits
    # And employee should see the ineligible family member disabled and unchecked
    # And employee should see the eligible family member enabled and checked
    # And employee should also see the reason for ineligibility

    # When employee switched to second employer
    # Then employee should not see the dental radio button
    # And employee should see the ineligible family member disabled and unchecked
    # And employee should see the eligible family member enabled and checked