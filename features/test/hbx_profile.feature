Feature: A valid HbxProfile exists
  I want to get a hbx profile
  
  Scenario: Successfully get hbx profile
    Given A valid hbx_profile exist
  
  Scenario: Successfully get hbx profile with traits
    Given A valid hbx_profile, with open_enrollment_coverage_period