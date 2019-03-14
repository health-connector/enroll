Feature: Employee termination and Re-hire functionality

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And this employer has a benefit application

  Scenario: Employer terminated EE with DOT as today
    Given staff role person logged in
    And ABC Widgets visit the Employee Roster
    And this employer click on one of their employees
#    Then they should see that employee's details
#    And employer click on pencil symbol next to employee status bar
#    Then employer should see the terminate button
#    And employer clicks on terminate button
#    Then employer should see the field to enter termination date
#    And employer clicks on terminate button with date as today
#    Then employer should see the terminated success flash notice

Scenario: Employer terminated EE with DOT in past greater than 60 days
  Given an employer exists
  And the employer has employees
  And the employer is logged in
  When they visit the Employee Roster
  And click on one of their employees
  Then they should see that employee's details
  And employer click on pencil symbol next to employee status bar
  Then employer should see the terminate button
  And employer clicks on terminate button
  Then employer should see the field to enter termination date
  And employer clicks on terminate button with date as past greater than 60 days
  Then employer should see the error flash notice

Scenario: Employer rehired EE from census detail page with rehire date in future
  Given an employer exists
  And the employer has employees
  And the employer is logged in
  When they visit the Employee Roster
  And click on one of their past terminated employee
  Then they should see that employee's details
  And employer click on pencil symbol next to employee status bar
  Then employer should see the rehire button
  And employer clicks on rehire button
  Then employer should see the field to enter rehire date
  And employer clicks on rehire button with date as today
  Then employer should see the rehired success flash notice

Scenario: Employer rehired EE from census detail page with rehire date in past ahead of termination date
  Given an employer exists
  And the employer has employees
  And the employer is logged in
  When they visit the Employee Roster
  And click on one of their past terminated employee
  Then they should see that employee's details
  And employer click on pencil symbol next to employee status bar
  Then employer should see the rehire button
  And employer clicks on rehire button
  Then employer should see the field to enter rehire date
  And employer clicks on rehire button with date as as past ahead of termination date
  Then employer should see the rehired error flash notice

