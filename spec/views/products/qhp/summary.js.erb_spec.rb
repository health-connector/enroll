# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "products/qhp/summary.js.erb" do
  let(:benefit_group) { double("BenefitGroup") }
  let(:hbx_enrollment) { instance_double(HbxEnrollment, shopping?: false) }
  let(:member_enrollment) { double(product: double, product_cost_total: 300.00, sponsor_contribution_total: 240.00) }
  let(:member_group) { double(group_enrollment: member_enrollment) }
  before :each do
    assign(:benefit_group, benefit_group)
    assign(:member_group, member_group)
    assign(:hbx_enrollment, hbx_enrollment)
    allow(benefit_group).to receive(:sole_source?).and_return(true)
    stub_template "shared/_summary.html.erb" => ''
    render template: "products/qhp/summary.js.erb"
  end

  it "should call account-detail" do
    expect(rendered).to match(/account-detail/)
    expect(rendered).to match(/all-plans/)
    expect(rendered).to match(/plan-summary/)
  end

  it "should call scroll" do
    expect(rendered).to match(/scroll/)
  end
end
