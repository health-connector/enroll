Feature: Employer can view their employees

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market
    And there is an employer ABC Widgets
    And ABC Widgets employer has a staff role
    And Hannah is a person
    And Hannah is census employee to ABC Widgets
    When staff role person logged in
    Then ABC Widgets employer visit the Employee Roster
    
  Scenario: Employer views their employees on their account
    Given employer selects one of their employees on Employee Roster
    And employer should see census employee's details
    Then employer clicks logout

  Scenario: Employer views their employees and terminates one employee
    Given employer views and clicks on Actions button for an Employee
    Then employer should see the terminate button
    When employer clicks on terminate button
    Then employer should see Enter termination date to remove text
    And employer clicks on Terminate Employee button with date as pastdate
    Then employer should see the terminated success flash notice
    When employer clicks on button terminated for datatable
    And employer clicks on terminated employee
    Then employer should see census employee's details
    When employer clicks on back button
    Then employer should see employee roaster
    Then employer clicks logout

   Scenario: Employer views their employees and this ER has linked EEs
    Given employer clicks on linked employee with address
    Then employer should not see the address on the roster
    And employer clicks on cancel button
    And employer clicks on linked employee without address
    Then employer should see the address on the roster
    And employer populates the address field
    And employer clicks on update employee
    Then employer should not see the address on the roster
    And employer clicks on cancel button
    And employer clicks on non-linked employee with address
    Then employer should not see the address on the roster
    And employer clicks on cancel button
    And employer clicks on non-linked employee without address
    Then employer should see the address on the roster
    And employer logs out
