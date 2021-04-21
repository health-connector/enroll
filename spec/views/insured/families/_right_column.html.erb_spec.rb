# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "insured/families/_right_column.html.erb" do
  def person
    random_value = rand(999_999_999)
    instance_double(
      "Person",
      full_name: "my full name",
      phones: [new_phone(random_value)],
      emails: [new_email],
      has_active_employee_role?: false,
      has_active_shopping_role?: true,
      has_consumer_role?: false
    )
  end

  def new_email
    instance_double(
      "Email",
      address: "test@example.com"
    )
  end

  def new_phone(random_value)
    double(
      "Phone",
      kind: "test#{random_value}"
    )
  end

  context "shows assignment date" do

    before :each do
      assign :person, person
      allow(view).to receive(:policy_helper).and_return(double("Policy", updateable?: true))
    end

    context "when employee setting is enabled" do
      it "should display the employee external links advertisement" do
        EnrollRegistry[:add_external_links].feature.stub(:is_enabled).and_return(true)
        EnrollRegistry[:add_external_links].setting(:employee_display).stub(:item).and_return(true)

        render partial: 'insured/families/right_column.html.erb'

        expect(rendered).to include("Earn a $100 Reward when you complete a qualifying ConnectWell activity.")
        expect(rendered).to include("href=\"https://www.mahealthconnector.org/business/employees/connectwell-for-employees")
      end
    end

    context "when employee setting is disabled" do
      it "should not display the employee external links advertisement" do
        EnrollRegistry[:add_external_links].feature.stub(:is_enabled).and_return(true)
        EnrollRegistry[:add_external_links].setting(:employee_display).stub(:item).and_return(false)

        render partial: 'insured/families/right_column.html.erb'

        expect(rendered).not_to include("Earn a $100 Reward when you complete a qualifying ConnectWell activity.")
        expect(rendered).not_to include("href=\"https://www.mahealthconnector.org/business/employees/connectwell-for-employees")
      end
    end
  end
end