# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "shared/_search.html.erb"  do |_variable|

  before :each do
    stub_template "_search.html.erb" => ''
    @q = 'sample'
    @broker_agency_profile = FactoryBot.create(:broker_agency_profile)
    render 'shared/search', url: benefit_sponsors.family_index_profiles_broker_agencies_broker_agency_profiles_path, q: @q, placeholder: "Last Name", remote: true, opts: { id: @broker_agency_profile.id }
  end

  it 'should have broker_agency_profile.id in id field' do
    expect(rendered).to have_selector("input#id[value=\"#{@broker_agency_profile.id}\"]", visible: false)
  end

  it "should have search box with id=q" do
    expect(rendered).to have_selector("input#q")
  end
end
