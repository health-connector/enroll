Feature: HBX Admin should be able to click the MA logo link

  Scenario: HBX Admin is on Landing Page
   Given a Hbx admin with read and write permissions exists
   When Hbx Admin logs on to the Hbx Portal
   And the Hbx Admin clicks on the logo link
   Then it should redirect to Health Care Website