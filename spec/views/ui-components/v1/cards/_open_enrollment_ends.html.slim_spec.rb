require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe "_open_enrollment_ends.html.slim", :type => :view, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:benefit_application) {initial_application}
  let(:current_effective_date) { TimeKeeper.date_of_record.end_of_month + 1.day + 1.month }
  let(:effective_period) {current_effective_date..current_effective_date.next_year.prev_day}
  let(:open_enrollment_period) {effective_period.min.prev_month..(Date.new(effective_period.min.year,effective_period.min.month,20))}
  let(:open_enrollment_end_date) { open_enrollment_period.max }

  before :each do
    benefit_application.update_attributes!(aasm_state: :enrollment_eligible, open_enrollment_period: open_enrollment_period, effective_period: effective_period)
    assign :current_plan_year, benefit_application
  end

  it "should render the correct date" do
    render "ui-components/v1/cards/open_enrollment_ends"
    expect(rendered).to have_content((open_enrollment_end_date - TimeKeeper.date_of_record).to_i)
  end

  context "Should not display the wrong date" do
    before do
      benefit_application.update_attributes!(aasm_state: :enrollment_eligible, open_enrollment_period: open_enrollment_period, effective_period: effective_period)
      assign :current_plan_year, benefit_application
      TimeKeeper.set_date_of_record_unprotected!(open_enrollment_end_date.prev_day)
    end

    after do
      TimeKeeper.set_date_of_record_unprotected!(Date.today)
    end

    it "should render the correct date" do
      render "ui-components/v1/cards/open_enrollment_ends"
      expect(rendered).not_to have_content((open_enrollment_end_date - Time.now.to_date).to_i)
      expect(rendered).to have_content((open_enrollment_end_date - TimeKeeper.date_of_record).to_i)
    end
  end
end
