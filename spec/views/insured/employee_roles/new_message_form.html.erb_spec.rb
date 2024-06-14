# frozen_string_literal: true

require 'rails_helper'

describe "insured/employee_roles/_new_message_form.html.erb" do
  let(:broker) do
    instance_double("Broker",
                    person: person)
  end

  let(:person) do
    instance_double("Person",
                    full_name: "my full name")
  end

  let(:hbx_enrollment) do
    instance_double("HbxEnrollment",
                    id: double("id"))
  end

  context "when not waived" do
    before :each do
      assign :broker, broker
      assign :hbx_enrollment, hbx_enrollment
      render "insured/employee_roles/new_message_form.html.erb"
    end

    it "should display the plan name" do
      expect(rendered).to match(/New Message.*recipient.*subject/mi)
    end

  end

end
