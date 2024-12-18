# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "insured/families/home.html.erb" do
  let(:current_user) {FactoryBot.create(:user)} #let(:person) { FactoryBot.create(:person, :with_family ) }
  let(:person) {FactoryBot.create(:person, :with_employee_role, :with_family)} #let(:person) { FactoryBot.create(:person, :with_family ) }
  let(:family) { FactoryBot.create(:family, :with_primary_family_member) }
  let(:current_user) {FactoryBot.create(:user,person: person)}

  let(:qle_first_of_month) { FactoryBot.create(:qualifying_life_event_kind, :effective_on_first_of_month) }
  let(:sep) do
    sep = family.special_enrollment_periods.new
    sep.effective_on_kind = 'first_of_month'
    sep.qualifying_life_event_kind = qle_first_of_month
    sep.qualifying_life_event_kind_id = qle_first_of_month.id
    sep.qle_on = Date.new(TimeKeeper.date_of_record.year, 0o4, 14)
    sep.admin_flag = true
    sep
  end

  before :each do
    stub_template "insured/families/_right_column.html.erb" => ''
    stub_template "insured/families/_qle_detail.html.erb" => ''
    stub_template "insured/families/_enrollment.html.erb" => ''
    stub_template "insured/families/_navigation.html.erb" => ''
    stub_template "insured/families/_shop_for_plans_widget.html.erb" => ''
    stub_template "insured/families/_apply_for_medicaid_widget.html.erb" => ''
    stub_template "app/views/ui-components/v1/modals/_help_with_plan.html.slim" => ''
    assign(:person, person)
    sign_in current_user
    assign(:family, family)
    render template: "insured/families/home.html.erb"
  end

  it "should display the title" do
    allow(family).to receive(:active_seps).and_return(false)
    expect(rendered).to have_selector('h1', text: "My #{Settings.site.short_name}")
  end

  it "should have plan-summary area" do
    allow(family).to receive(:active_seps).and_return(false)
    expect(rendered).to have_selector('div#plan-summary')
  end

  it "should display 'existing SEP - Eligible to enroll' partial if there is an active admin SEP" do
    assign(:active_sep, sep)
    render template: "insured/families/home.html.erb"
    expect(rendered).to have_selector('div#qle-details-for-existing-sep')
  end

  it "should not display 'existing SEP - Eligible to enroll' partial if there is no active admin SEP" do
    assign(:active_sep, [])
    render template: "insured/families/home.html.erb"
    expect(rendered).to_not have_selector('div#qle-details-for-existing-sep')
  end

end
