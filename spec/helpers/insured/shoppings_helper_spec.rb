# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insured::ShoppingsHelper, :type => :helper, dbclean: :after_each do
  let(:subject)  { Class.new { extend Insured::ShoppingsHelper } }

  before :each do
    EnrollRegistry[:continuous_plan_shopping].feature.stub(:is_enabled).and_return(false)
  end

  describe "#is_eligible_for_dental?" do
    let(:site) { FactoryGirl.create(:benefit_sponsors_site,  :with_benefit_market, :dc, :as_hbx_profile) }

    let(:organization) do
      FactoryGirl.create(:benefit_sponsors_organizations_general_organization,
                         :with_aca_shop_dc_employer_profile_initial_application,
                         site: site)
    end

    let(:employer_profile) { organization.employer_profile }


    let(:active_bg) { double("ActiveBenefitGroup", plan_year: double("ActivePlanYear")) }
    let(:renewal_bg) { double("RenewalBenefitGroup", plan_year: double("RenewingPlanYear")) }
    let!(:sep) { FactoryGirl.create(:special_enrollment_period, family: family, effective_on: TimeKeeper.date_of_record)}
    let(:employee_role) { FactoryGirl.create(:employee_role, employer_profile: employer_profile)}
    let(:census_employee) { double("CensusEmployee", active_benefit_group: active_bg, employer_profile: employer_profile)}
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: employee_role.person)}

    before do
      allow(employee_role).to receive(:census_employee).and_return census_employee
      allow(employee_role).to receive(:can_enroll_as_new_hire?).and_return false
    end

    context "when ER is an initial ER" do

      before do
        allow(census_employee).to receive(:active_benefit_package).and_return active_bg
        allow(census_employee).to receive(:renewal_published_benefit_package).and_return nil
      end

      it "should return true if active benefit group offers dental" do
        allow(active_bg).to receive(:is_offering_dental?).and_return true
        expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq true
      end

      it "should return false if active benefit group not offers dental" do
        allow(active_bg).to receive(:is_offering_dental?).and_return false
        expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq false
      end
    end

    context "when ER is in renewing period" do

      before do
        allow(census_employee).to receive(:active_benefit_package).and_return nil
        allow(census_employee).to receive(:renewal_published_benefit_package).and_return renewal_bg
      end

      context "when EE is in renewal open enrollment & clicked on shop for plans" do

        it "should return true if renewal benefit group offers dental" do
          allow(renewal_bg).to receive(:is_offering_dental?).and_return true
          expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq true
        end

        it "should return false if renewal benefit group not offers dental" do
          allow(renewal_bg).to receive(:is_offering_dental?).and_return false
          expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq false
        end
      end

      context "when EE selects SEP & effective_on does not covers under active plan year period", dbclean: :after_each do

        before do
          allow(census_employee).to receive(:benefit_package_for_date).and_return(active_bg)
          allow(census_employee).to receive(:active_benefit_package).and_return nil
          allow(census_employee).to receive(:renewal_published_benefit_package).and_return active_bg
          allow(active_bg).to receive(:is_offering_dental?).and_return true
          allow(sep).to receive(:is_eligible?).and_return true
          allow(helper).to receive(:is_covered_plan_year?).with(active_bg.plan_year, sep.effective_on).and_return false
        end

        it "should return true if active benefit group offers dental" do
          allow(active_bg).to receive(:is_offering_dental?).and_return true
          expect(helper.is_eligible_for_dental?(employee_role, "change_by_qle", nil, nil)).to eq true
        end

        it "should return false if active benefit group not offers dental" do
          allow(active_bg).to receive(:is_offering_dental?).and_return false
          expect(helper.is_eligible_for_dental?(employee_role, "change_by_qle", nil, nil)).to eq false
        end
      end

      context "when EE selects SEP & effective_on covers under renewal plan year period", dbclean: :after_each do

        before do
          allow(census_employee).to receive(:benefit_package_for_date).and_return(renewal_bg)
          allow(census_employee).to receive(:active_benefit_package).and_return nil
          allow(census_employee).to receive(:renewal_published_benefit_package).and_return renewal_bg
          allow(active_bg).to receive(:is_offering_dental?).and_return true
          allow(sep).to receive(:is_eligible?).and_return true
          allow(helper).to receive(:is_covered_plan_year?).with(renewal_bg.plan_year, sep.effective_on).and_return true
        end

        it "should return true if renewal benefit group offers dental" do
          allow(renewal_bg).to receive(:is_offering_dental?).and_return true
          expect(helper.is_eligible_for_dental?(employee_role, "change_by_qle", nil, nil)).to eq true
        end

        it "should return false if renewal benefit group not offers dental" do
          allow(renewal_bg).to receive(:is_offering_dental?).and_return false
          expect(helper.is_eligible_for_dental?(employee_role, "change_by_qle", nil, nil)).to eq false
        end
      end

      context "when EE is in new hire enrollment period" do
        before do
          allow(census_employee).to receive(:active_benefit_package).and_return active_bg
          allow(census_employee).to receive(:renewal_published_benefit_package).and_return nil
          allow(employee_role).to receive(:can_enroll_as_new_hire?).and_return true
        end
        it "should return true if active benefit group offers dental" do
          allow(active_bg).to receive(:is_offering_dental?).and_return true
          expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq true
        end

        it "should return false if active benefit group not offers dental" do
          allow(active_bg).to receive(:is_offering_dental?).and_return false
          expect(helper.is_eligible_for_dental?(employee_role, nil, nil, nil)).to eq false
        end
      end
    end
  end
end
