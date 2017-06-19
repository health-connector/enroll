Feature: Document
  In order for admin to manage their employers Documents

  Scenario: An Admin should be able to upload document
    Given a Hbx admin with read and write permissions exists
    When Hbx Admin logs on to the Hbx Portal
    When the admin goes to the documents tab directly
    Then the admin should see upload button
    When the admin clicks upload button
    Then the admin should see model box with file upload
    And the admin fill the document form
    Then the admin clicks the upload button in popup
    Then the admin should see the document list
    And the admin clicks document type
    Then the admin should see Download,Cancel,Print Option