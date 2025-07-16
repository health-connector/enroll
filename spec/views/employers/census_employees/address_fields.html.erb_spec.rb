# frozen_string_literal: true

require 'rails_helper'

describe "employers/census_employees/_address_fields", dbclean: :after_each do
  let(:person) { FactoryBot.create(:person) }
  let(:address) { FactoryBot.create(:address, person: person) }
  let(:census_employee) { FactoryBot.build(:census_employee, first_name: person.first_name, last_name: person.last_name, dob: person.dob, ssn: person.ssn)}

  before :each do
    mock_form = ActionView::Helpers::FormBuilder.new(:address, address, view, {})
    assign(:census_employee, census_employee)
    render "employers/census_employees/address_fields", :f => mock_form
  end

  it "should have one select option" do
    expect(rendered).to match(/Address/)
    expect(rendered).to have_selector("select", count: 1)
  end

  it "should have many options for state field" do
    expect(rendered).to have_selector("option", count: State::NAME_IDS.count + 1)
    State::NAME_IDS.each do |item|
      expect(rendered).to have_selector("option[value='#{item.last}']", count: 1)
    end
  end
end
