Feature: Add, Edit and Delete security questions

  Scenario: Hbx Admin can add new security question
    Given Hbx Admin exists
    When Hbx Admin logs on to the Hbx Portal
    Then Hbx Admin click on Config
    And Hbx Admin should see Security Question link
    And Hbx Admin clicks on Security Question link
    And there is 0 questions available in the list
    When Hbx Admin clicks on New Question link
    Then Hbx Admin should see New Question form
    And Hbx Admin fill out New Question form detail
    When Hbx Admin submit the question form
    Then there is 1 questions available in the list

  Scenario: Hbx Admin can edit and update an existing security question
    Given Hbx Admin exists
    When Hbx Admin logs on to the Hbx Portal
    Then Hbx Admin click on Config
    And there is 1 preloaded security questions
    And Hbx Admin should see Security Question link
    And Hbx Admin clicks on Security Question link
    And there is 1 questions available in the list
    When Hbx Admin clicks on Edit Question link
    Then Hbx Admin should see Edit Question form
    And Hbx Admin update the question title
    When Hbx Admin submit the question form
    Then there is 1 questions available in the list
    And the question title updated successfully

  Scenario: Hbx Admin can delete an existing security question
    Given Hbx Admin exists
    When Hbx Admin logs on to the Hbx Portal
    Then Hbx Admin click on Config
    And there is 1 preloaded security questions
    And Hbx Admin should see Security Question link
    And Hbx Admin clicks on Security Question link
    And there is 1 questions available in the list
    When Hbx Admin clicks on Delete Question link
    And I confirm the delete question popup
    Then there is 0 questions available in the list
