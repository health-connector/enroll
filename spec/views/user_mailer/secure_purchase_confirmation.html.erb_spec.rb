require "rails_helper"

RSpec.describe "views/user_mailer/secure_purchase_confirmation.html.erb" do

  let(:family) { FactoryGirl.build(:family, :with_primary_family_member_and_dependent)}
  let(:primary) { family.primary_family_member }
  let(:benefit_group) { FactoryGirl.create(:benefit_group)}
  let(:plan) { FactoryGirl.create(:plan)}
  let!(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, benefit_group:benefit_group,plan: plan, effective_on:TimeKeeper.date_of_record.next_month.beginning_of_month,household: family.active_household)}
  let(:person) { FactoryGirl.create(:person)}
  let(:decorated_plan) { PlanCostDecorator.new(plan, hbx_enrollment, benefit_group, hbx_enrollment.plan) }

  before :each do
    assign(:person, person)
    assign(:market_kind, "shop")
    assign(:plan, decorated_plan)
    assign(:enrollment, hbx_enrollment)
    render :template => "user_mailer/secure_purchase_confirmation.html.erb"
  end

  context "with enrollemnt future start date" do

    it 'should display contact center hours for Monday-Friday & Saturday' do
      expect(rendered).to match /Monday-Friday 8:00am - 8:00pm, Saturday 10:00am - 5.00pm/i
    end
  end

  context "with enrollemnt effective_on started" do

    before :each do
      hbx_enrollment.update_attributes(effective_on:TimeKeeper.date_of_record.beginning_of_month)
      assign(:enrollment, hbx_enrollment)
      render :template => "user_mailer/secure_purchase_confirmation.html.erb"
    end

    it 'should display contact center hours for Monday-Friday' do
      expect(rendered).to match /Monday-Friday 8:00am - 6:00pm/i
    end
  end
end

