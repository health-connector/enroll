# frozen_string_literal: true

require "rails_helper"

RSpec.describe "benefit_sponsors/profiles/employers/employer_profiles/my_account/accounts/_payment_history.html.erb", type: :view do
  let(:paid_on_date) { Date.new(2021, 1, 2) }
  let(:payment) do
    OpenStruct.new(
      paid_on: paid_on_date,
      amount: BigDecimal("100.00"),
      method_kind: "ACH"
    )
  end

  before do
    view.extend BenefitSponsors::ApplicationHelper
    assign(:wf_url, nil)
    assign(:employer_profile, double("EmployerProfile", id: "12345"))
    assign(:benefit_sponsorship, double("BenefitSponsorship", has_financial_transactions?: true))
    assign(:benefit_sponsorship_account, double("BenefitSponsorshipAccount", financial_transactions: []))
    assign(:payments, [payment])
  end

  it "renders formatted payment date using format_date helper" do
    render partial: "benefit_sponsors/profiles/employers/employer_profiles/my_account/accounts/payment_history"
    expect(rendered).to include("01/02/2021")
  end
end
