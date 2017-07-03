Feature: Lock and Unlock user account
  In order to lock/unlock user
  User should have the role of an admin

  Scenario: Admin can change the locked status of the user
    Given Hbx Admin exists
    When Hbx Admin logs on to the Hbx Portal
    Then there are 1 preloaded locked user accounts
    When Hbx Admin clicks on the User Accounts tab
    Then Hbx Admin should see the list of primary applicants and an Action button
    When Hbx Admin clicks on the Action button
    Then Hbx Admin should see Unlock/Lock Account link
    When Hbx Admin clicks on Unlock/Lock Account link
    Then there is a confirm link on in the list
    When I click on the confirm link
    Then the locked user should be in the list
