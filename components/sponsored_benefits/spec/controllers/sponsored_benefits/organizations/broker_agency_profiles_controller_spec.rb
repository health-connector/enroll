require 'rails_helper'
require "#{SponsoredBenefits::Engine.root}/spec/shared_contexts/sponsored_benefits"

module SponsoredBenefits
  RSpec.describe Organizations::BrokerAgencyProfilesController, type: :controller, dbclean: :around_each  do
    routes { SponsoredBenefits::Engine.routes }
    include_context "set up broker agency profile for BQT, by using configuration settings"
    let!(:user_with_hbx_staff_role) { FactoryGirl.create(:user, :with_hbx_staff_role) }
    let!(:person) { FactoryGirl.create(:person, user: user_with_hbx_staff_role )}

    context "#employers" do
      before do
        sign_in user_with_hbx_staff_role
        xhr :get, :employers, {id: owner_profile.id}
      end

      it "should set datatable instance variable" do
        expect(assigns(:datatable).class).to eq Effective::Datatables::BrokerAgencyPlanDesignOrganizationDatatable
      end
    end
  end
end
