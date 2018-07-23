require 'rails_helper'

RSpec.describe Enrollments::EnrollmentEligibility, type: :model do

  subject { described_class.new }

  describe "Common behavior" do

    it "should use today's system date if no eligible_on date is supplied"
    it "should use all market kinds on the site if no market_kinds list is supplied"
    it "should initialize with all special_enrollment_periods for the supplied family, elibility_on and market_kinds parameters"
    it "should initialize with next open_enrollment_period for the supplied family, elibility_on and market_kinds parameters"
    it "should initialize with active open_enrollment_period for the supplied family, elibility_on and market_kinds parameters"

  end

  describe "A person active in the SHOP Market" do

    it "should find the family with whom the person is the primary member"
    it "should find all the employer sponsors where the person is a member"
    it "should find all past and present SHOP special_enrollment_periods for the family"

    context "and on the eligibility_on date the primary family member is in new hire status with an employer sponsor" do

      context "and the eligibility_on date is within the new_hire_enrollment_period" do
        it "shop market enrollment periods should include the sponsor"
      end

      context "and the eligibility_on date preceeds the employer sponsor's probation period end date" do
        it "shop market enrollment periods should not include the sponsor"
      end

      context "and the eligibility_on date is after the new_hire_enrollment_period" do
        it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
      end
    end

    context "and on the eligibility_on date the primary family member is under active status with an employer sponsor" do

      context "and on the eligibility_on date the employer sponsor is under open enrollment" do
        it "shop market enrollment periods should include the sponsor's active open_enrollment_period"
      end

      context "and on the eligibility_on date the employer sponsor is not under open enrollment" do
        it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
      end

      context "and on the eligibility_on date the family has an active QLE" do
        it "shop market enrollment periods should include a special_enrollment_period for the QLE"
        it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
      end

      context "and on the eligibility_on date the family has no SHOP active QLEs" do
        it "shop market enrollment periods should not include a SEP enrollment period"

        context "and the family had a SHOP QLE prior to eligibility_on date" do
          it "shop market enrollment periods should not include a SEP enrollment period"
          it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
        end
      end

      context "and the primary family member is active with more than one employer sponsor" do

        context "and no employer sponsors are under open enrollment" do
          it "shop market enrollment periods should include next open_enrollment_period for each employer sponsor"
        end

        context "and one employer sponsor is under open enrollment" do
          it "shop market enrollment periods should include the inactive sponsor's next open_enrollment_period"
          it "shop market enrollment periods should include the active sponsor's open_enrollment_period"
        end
      end
    end

    context "and on the eligibility_on date the primary family member is under terminated status with the employer" do

      context "and the employee termination date is within the COBRA election period" do
      end

      context "and the employee termination date is outside the COBRA election period" do
      end

      context "and the family had a SHOP QLE prior to effective date" do
        it "should include the enrollment_period for that employer"
      end

      context "and the family had a SHOP QLE following the termination date" do
        it "should not include the enrollment_period for that employer"
      end
    end

    context "and on the eligibility_on date the primary family member is under COBRA coverage status with employer" do

      context "and effective on date is prior to the cobra_enrollment_period" do
        it "shop market enrollment periods should include the cobra_enrollment_period"
      end

      context "and effective on date is within cobra_enrollment_period" do
        it "shop market enrollment periods should include the cobra_enrollment_period"
      end

      context "and effective on date is after cobra_enrollment_period" do
        it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
      end
    end
  end

  describe "A person active on the Individual Market" do

    context "and the individual market is under open_enrollment_period" do
      it "individual market enrollment periods should include the active open_enrollment_period"
    end

    context "and the individual market is not under open_enrollment_period" do
      it "individual market enrollment periods should include the next open_enrollment_period"

      context "and the family qualifies for native_american_enrollment_period" do
        it "individual market enrollment periods should include the next native_american open_enrollment_period"
      end
    end
  end

  describe "A person active on the FEHB (Congress) Market" do
  end

  describe "A primary family member on both SHOP and Individual Market" do

    it "shop market enrollment periods should include the sponsor's next open_enrollment_period"
    it "individual market enrollment periods should include the next open_enrollment_period"

  end

end
