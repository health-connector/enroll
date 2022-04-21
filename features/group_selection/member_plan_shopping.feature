Feature: EE plan purchase

  Background: Setup site, employer, and benefit application
	Given a CCA site exists with a benefit market
	Given benefit market catalog exists for enrollment_open initial employer that has both health and dental benefits
	And there is an employer Acme Inc.
	And Acme Inc. employer has a staff role
	Given Continuous plan shopping is enabled
	Given staff role person logged in
	And employer Acme Inc. has enrollment_open benefit application with dental
	And Acme Inc. employer visit the Employee Roster
	And there is a census employee record for Patrick Doe for employer Acme Inc.
	Then Employer logs out

  Scenario: New employee shops for both health and dental plan
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
	Then Employee should see the dependents page
	When Employee clicks continue on the dependents page
	Then Employee should see the group selection page
	Then Employee should see enroll & waive buttons
	When Employee clicks continue button on group selection page for dependents
	When Employee selects a health plan on the plan shopping page
	And Employee selects a dental plan on the plan shopping page
	When Employee clicks on Confirm button on the coverage summary page
	Then Employee should see both health & dental plans on receipt page
	Then Employee should see the receipt page

  Scenario: New employee shops for dental plan only
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
	Then Employee should see the dependents page
	When Employee clicks continue on the dependents page
	Then Employee should see the group selection page
	Then Employee should see enroll & waive buttons
	And Employee waives health plan
	When Employee clicks continue button on group selection page for dependents
	When Employee selects a dental plan on the plan shopping page
	Then Employee clicks no on choose coverage for household
	When Employee clicks on Confirm button on the coverage summary page
	Then Employee should see dental enrollment text on receipt page


