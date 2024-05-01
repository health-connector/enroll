require 'rails_helper'

describe "shared/_alph_paginate_remote.html.erb" do

  context "ALL link to be added" do

    context "url_params are present" do
      let(:url_params) { {"id":"12345678", "profile_id":"987654321"} }
      it "adds url_params to href url" do
        render "shared/alph_paginate_remote",
               url: benefit_sponsors.family_index_profiles_broker_agencies_broker_agency_profiles_path,
               alphs: [],
               all: benefit_sponsors.family_index_profiles_broker_agencies_broker_agency_profiles_path,
               url_params: url_params
        expect(rendered).to have_link("ALL", href: "/benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/family_index?id=12345678&profile_id=987654321")
      end

    end

    context "url_params are absent" do
      let(:url_params) { nil }
      it "adds url_params to href url" do
        render "shared/alph_paginate_remote",
               url: benefit_sponsors.family_index_profiles_broker_agencies_broker_agency_profiles_path,
               alphs: [],
               all: benefit_sponsors.family_index_profiles_broker_agencies_broker_agency_profiles_path,
               url_params: url_params
        expect(rendered).to have_link("ALL", href: "/benefit_sponsors/profiles/broker_agencies/broker_agency_profiles/family_index")
      end
    end
  end
end
