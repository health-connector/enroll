Feature: Conversion employees can purchase coverage only through renewing plan year
  In order to make employees purchase coverage only using renewal plan year
  Employee should be blocked from buying coverage under off-exchange plan year

  Scenario: New Hire should not get effective date before renewing plan year start date
    Given a CCA site exists with a benefit market
    Given Qualifying life events are present
    And there is an employer ACME Widgets, Inc.
    # Benefit application model seems to suggest that enrollment_open is considered renewing?
    And this employer has enrollment_open benefit application with offering health and dental
    And ACME Widgets, Inc. employer has a staff role
    Given staff role person logged in
    And ACME Widgets, Inc. employer visit the Employee Roster
    Then Employer logs out
    And Employee has not signed up as an HBX user
    And Patrick Doe visits the employee portal
    When Patrick Doe creates an HBX account
    And I select the all security question and give the answer
    When I have submitted the security questions
    When Employee goes to register as an employee
    Then Employee should see the employee search page
    When Employee enters the identifying info of Patrick Doe
    Then Employee should see the matched employee record form
    When Employee accepts the matched employer

    When Employee completes the matched employee form for Patrick Doe
    And Employee sees the Household Info: Family Members page and clicks Continue
    And Employee sees the Choose Coverage for your Household page and clicks Continue
    And Employee selects the first plan available
    And Employee clicks Confirm
    And Employee sees the Enrollment Submitted page and clicks Continue

    Then Employee Patrick Doe should see their plan start date on the page

  Scenario: New Hire can't buy coverage before open enrollment of renewing plan year through Shop for Plans

    Given a CCA site exists with a benefit market
    And benefit market has prior benefit market catalog
    And there is an employer ABC Widgets
    And this employer had a active and renewing draft application

    Given there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    When Employee clicks "Shop for Plans" on my account page
    Then Employee should see the group selection page
    When Employee clicks continue on the group selection page

    # At this point renewal applicaiton open enrollmetn period is Wed, 01 May 2019..Wed, 22 May 2019
    # but today's date April 2nd. So they shouldn't be able to buy coverage?
    # Plan selection page
    # Shouldn't see the plans here?
    Then Employee should see the list of plans

    # Shouldn't be able to select plan?
    And Employee selects the first plan available
    And Employee clicks Confirm
    When Employee clicks continue on the group selection page

    # This is the intended result
    Then Employee should see "employer-sponsored benefits not found" error message

  Scenario: New Hire can't buy coverage before open enrollment of renewing plan year through New Hire badge
    Given a CCA site exists with a benefit market
    And benefit market has prior benefit market catalog
    And there is an employer ABC Widgets
    And this employer had a active and renewing draft application

    Given there exists Patrick Doe employee for employer ABC Widgets
    And employee Patrick Doe has current hired on date
    And employee Patrick Doe already matched with employer ABC Widgets and logged into employee portal
    When Employee clicks on New Hire Badge
    When Employee clicks continue on the group selection page

    # Currently they can select plans
    # They shouldn't be able to do these steps
    And Employee selects the first plan available
    And Employee clicks Confirm
    When Employee clicks continue on the group selection page



    # This should be the intended result
    Then Patrick Doe should see "open enrollment not yet started" error message

  Scenario: New Hire can't buy coverage under off-exchange plan year using QLE
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employee has current hired on date
      And Soren White already matched and logged into employee portal
      When Employee click the "Married" in qle carousel
      And Employee select a past qle date
      Then Employee should see confirmation and clicks continue
      Then Employee should see family members page and clicks continue
      Then Employee should see the group selection page
      When Employee clicks continue on the group selection page
      Then Employee should see "employer-sponsored benefits not found" error message

  Scenario: New Hire can buy coverage during open enrollment of renewing plan year
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employer for Soren White is under open enrollment
      And Employee has current hired on date
      And Soren White already matched and logged into employee portal
      When Employee clicks on New Hire Badge
      When Employee clicks continue on the group selection page
      Then Employee should see the list of plans
      And I should not see any plan which premium is 0
      When Employee selects a plan on the plan shopping page
      Then Soren White should see coverage summary page with renewing plan year start date as effective date
      Then Soren White should see the receipt page with renewing plan year start date as effective date
      Then Employee should see "my account" page with enrollment

  Scenario: Existing Employee should not get effective date before renewing plan year start date
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employee has not signed up as an HBX user
      And Soren White visits the employee portal
      When Soren White creates an HBX account
      And I select the all security question and give the answer
      When I have submitted the security questions
      And I select the all security question and give the answer
      When I have submitted the security questions
      When Employee goes to register as an employee
      Then Employee should see the employee search page
      When Employee enters the identifying info of Soren White
      Then Employee should see the matched employee record form
      Then Employee Soren White should have the renewing plan year start date as earliest effective date
      Then Employee Soren White should not see earliest effective date on the page

  Scenario: Existing Employee can't buy coverage before open enrollment of renewing plan year
     Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employer for Soren White published renewing plan year
      And Soren White already matched and logged into employee portal
      When Employee clicks "Shop for Plans" on my account page
      When Employee clicks continue on the group selection page
      Then Soren White should see "open enrollment not yet started" error message

  Scenario: Existing Employee can't buy coverage under off-exchange plan year using QLE
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employer for Soren White published renewing plan year
      And Soren White already matched and logged into employee portal
      When Employee click the "Married" in qle carousel
      And Employee select a past qle date
      Then Employee should see confirmation and clicks continue
      Then Employee should see family members page and clicks continue
      Then Employee should see the group selection page
      When Employee clicks continue on the group selection page
      Then Soren White should see "open enrollment not yet started" error message

  Scenario: Existing Employee can buy coverage during open enrollment of renewing plan year using QLE
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employer for Soren White is under open enrollment
      And Soren White already matched and logged into employee portal
      When Employee click the "Married" in qle carousel
      And Employee select a past qle date
      Then Employee should see confirmation and clicks continue
      Then Employee should see family members page and clicks continue
      Then Employee should see the group selection page
      When Employee clicks continue on the group selection page
      # Then Employee should see the list of plans
      # And I should not see any plan which premium is 0
      # When Employee selects a plan on the plan shopping page
      # Then Soren White should see coverage summary page with renewing plan year start date as effective date
      # Then Soren White should see the receipt page with renewing plan year start date as effective date
      # Then Employee should see "my account" page with enrollment

  Scenario: Existing Employee can buy coverage during open enrollment of renewing plan year
    Given Conversion Employer for Soren White exists with active and renewing plan year
      And Employer for Soren White is under open enrollment
      And Soren White already matched and logged into employee portal
      When Employee clicks "Shop for Plans" on my account page
      When Employee clicks continue on the group selection page
      Then Employee should see the list of plans
      And I should not see any plan which premium is 0
      When Employee selects a plan on the plan shopping page
      Then Soren White should see coverage summary page with renewing plan year start date as effective date
      Then Soren White should see the receipt page with renewing plan year start date as effective date
      Then Employee should see "my account" page with enrollment

  Scenario: Existing Employee can buy coverage from multiple employers during open enrollment of renewing plan year
    Given Conversion Employer for Soren White exists with active and renewing plan year
    Given Multiple Conversion Employers for Soren White exist with active and renewing plan years
      And Employer for Soren White is under open enrollment
      And Other Employer for Soren White is under open enrollment
      And Current hired on date all employments
      And Soren White matches all employee roles to employers and is logged in
      And Soren White has New Hire Badges for all employers
      When Soren White click the first button of new hire badge
      Then Employee should see the group selection page
      When Employee clicks continue on the group selection page
      Then Employee should see the plan shopping welcome page
      Then Soren White should see the 1st ER name
      Then Employee should see the list of plans
      When Employee selects a plan on the plan shopping page
      Then Employee should see the coverage summary page
      Then Soren White should see the 1st ER name
      When Employee clicks on Confirm button on the coverage summary page
      Then Soren White should see the 1st ER name
      Then Employee should see the receipt page
      Then Employee should see the "my account" page
      Then Soren White should see the 1st ER name
      And Soren White should see New Hire Badges for 2st ER

      When Soren White click the button of new hire badge for 2st ER
      Then Employee should see the group selection page
      When Employee clicks continue on the group selection page
      Then Soren White should see the 2st ER name
      Then Employee should see the plan shopping welcome page
      Then Employee should see the list of plans
      When Employee selects a plan on the plan shopping page
      Then Employee should see the coverage summary page
      Then Soren White should see the 2st ER name
      When Employee clicks on Confirm button on the coverage summary page
      Then Soren White should see the 2st ER name
      Then Employee should see the receipt page
      Then Employee should see the "my account" page
      Then Soren White should see the 2st ER name
