# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "exchanges/employer_applications/_v2_xml_result.html.erb", dbclean: :after_each do
  context "when a success message is present" do
    before :each do
      assign :success_message, "V2 XML downloaded successfully."
      render partial: "exchanges/employer_applications/v2_xml_result"
    end

    it "renders the success message in green" do
      expect(rendered).to match(/style="color:green"[^>]*>V2 XML downloaded successfully\./)
    end
  end

  context "when an error message is present" do
    before :each do
      assign :error_message, "An error occurred during download"
      render partial: "exchanges/employer_applications/v2_xml_result"
    end

    it "renders the error message in red" do
      expect(rendered).to match(/style="color:red"[^>]*>An error occurred during download/)
    end
  end

  it "renders the hidden success_message placeholder in green for the upload flow" do
    render partial: "exchanges/employer_applications/v2_xml_result"
    expect(rendered).to match(/id="success_message" style="color:green;display:none"/)
  end

  it "closes by removing only the result row, leaving the applications table intact" do
    render partial: "exchanges/employer_applications/v2_xml_result"
    expect(rendered).to match(/\$\('tr\.v2-xml-result-row'\)\.remove\(\);/)
    expect(rendered).not_to match(/tr\.child-row/)
  end
end
