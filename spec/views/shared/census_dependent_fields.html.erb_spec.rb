# frozen_string_literal: true

require 'rails_helper'

describe "shared/census_dependent_fields.html.erb", dbclean: :after_each do
  let(:employer_profile) { FactoryBot.create(:employer_profile) }
  let(:census_employee) { CensusEmployee.new }

  before :each do
    census_dependent = census_employee.census_dependents.build
    mock_form = ActionView::Helpers::FormBuilder.new(:census_dependent, census_dependent, view, {})
    render "shared/census_dependent_fields", :f => mock_form
  end

  it "should have two radio options" do
    expect(rendered).to have_selector("input[type='radio']", count: 2)
  end

  it "should not have checked checkbox option" do
    expect(rendered).to have_selector("input[checked='checked']", count: 0)
  end
end
