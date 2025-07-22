# frozen_string_literal: true

require 'rails_helper'

describe "shared/_email_fields.html.erb" do
  let(:email) { FactoryBot.build(:email, kind: 'home') }

  before :each do
    mock_form = ActionView::Helpers::FormBuilder.new(:email, email, view, {})
    render "shared/email_fields", :f => mock_form
  end

  it "should have email area" do
    expect(rendered).to have_selector("div.email")
  end

  it "should have a hidden input field" do
    expect(rendered).to have_selector('input[type="hidden"]', visible: false)
  end

  it "should have a required input field" do
    expect(rendered).to_not have_selector('input[required="required"]')
  end

  it "should have a required input field with asterisk" do
    expect(rendered).to_not have_selector('input[placeholder="Home Email Address *"]')
  end
end
