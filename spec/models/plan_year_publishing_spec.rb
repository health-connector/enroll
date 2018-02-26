require "rails_helper"

describe PlanYear, "that is:
- finished open enrollment
- paid the binder
- is configured to wait for the 15th of the month
" do

  let(:employer_profile) { EmployerProfile.new(:aasm_state => "binder_paid") }
  let(:threshold_day) { Settings.aca.shop_market.employer_transmission_day_of_month }
  let(:monthly_oe_end_on) { Settings.aca.shop_market.open_enrollment.monthly_end_on }

  before :each do
    allow(PlanYear).to receive(:transmit_employers_immediately?).and_return(false)
    allow(TimeKeeper).to receive(:date_of_record).and_return(current_date)
  end

  subject do
    PlanYear.new({
      :aasm_state => "enrolled",
      :open_enrollment_end_on => Date.new(2017, 6, monthly_oe_end_on),
      :start_on => Date.new(2017, 7, 1),
      :employer_profile => employer_profile
    })
  end

  describe "and has not reached threshold date" do
    let(:current_date) { Date.new(2017, 6, threshold_day - 1) }

    it "is NOT eligible for export" do
      expect(subject.eligible_for_export?).to be_falsey
    end

  end

  describe "and has reached threshold date" do
    let(:current_date) { Date.new(2017, 6, threshold_day) }

    it "is eligible for export" do
      expect(subject.eligible_for_export?).to be_truthy
    end

  end
end

describe PlanYear, "that is:
- finished open enrollment
- paid the binder
- is *NOT* configured to wait for the 15th of the month
" do

  let(:employer_profile) { EmployerProfile.new(:aasm_state => "binder_paid") }
  let(:monthly_oe_end_on) { Settings.aca.shop_market.open_enrollment.monthly_end_on }
  let(:threshold_day) { Settings.aca.shop_market.employer_transmission_day_of_month }

  before :each do
    allow(PlanYear).to receive(:transmit_employers_immediately?).and_return(true)
    allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(2017,6,threshold_day-1))
  end

  subject do
    PlanYear.new({
      :aasm_state => "enrolled",
      :open_enrollment_end_on => Date.new(2017, 6, monthly_oe_end_on),
      :start_on => Date.new(2017, 7, 1),
      :employer_profile => employer_profile
    })
  end

  it "is eligible for export" do
    expect(subject.eligible_for_export?).to be_truthy
  end
end

describe PlanYear, "that is:
- finished renewal open enrollment
- is configured to wait for the threshold day of the month
- has reached the threshold date
" do

  let(:employer_profile) { EmployerProfile.new(:aasm_state => "enrolled") }
  let(:monthly_oe_end_on) { Settings.aca.shop_market.renewal_application.monthly_open_enrollment_end_on }
  let(:threshold_day) { Settings.aca.shop_market.employer_transmission_day_of_month }

  before :each do
    allow(PlanYear).to receive(:transmit_employers_immediately?).and_return(false)
    allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(2017,6,threshold_day))
  end

  subject do
    PlanYear.new({
      :aasm_state => "renewing_enrolled",
      :open_enrollment_end_on => Date.new(2017, 6, monthly_oe_end_on),
      :start_on => Date.new(2017, 7, 1),
      :employer_profile => employer_profile
    })
  end

  it "is eligible for export" do
    expect(subject.eligible_for_export?).to be_truthy
  end
end

describe PlanYear, "that is:
- finished renewal open enrollment
- is *NOT* configured to wait for the threshold day of the month
" do

  let(:employer_profile) { EmployerProfile.new(:aasm_state => "enrolled") }
  let(:threshold_day) { Settings.aca.shop_market.employer_transmission_day_of_month }
  let(:monthly_oe_end_on) { Settings.aca.shop_market.renewal_application.monthly_open_enrollment_end_on }

  before :each do
    allow(PlanYear).to receive(:transmit_employers_immediately?).and_return(true)
    allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(2017,6,threshold_day-1))
  end

  subject do
    PlanYear.new({
      :aasm_state => "renewing_enrolled",
      :open_enrollment_end_on => Date.new(2017, 6, monthly_oe_end_on),
      :start_on => Date.new(2017, 7, 1),
      :employer_profile => employer_profile
    })
  end

  it "is eligible for export" do
    expect(subject.eligible_for_export?).to be_truthy
  end
end
