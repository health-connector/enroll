require 'rails_helper'

module BenefitSponsors
  RSpec.describe SitesController, type: :controller, dbclean: :after_each do
    routes { BenefitSponsors::Engine.routes }

    let!(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }

    describe "non-admin users" do
      let(:user) { create :user }

      before do
        sign_in user
        get :index
      end

      it "can't get an index of sites" do
        expect(response).to have_http_status(:redirect)
      end
    end

    describe 'admin users' do
      let(:user) { create(:user, :hbx_staff) }

      before do
        sign_in user
        get :index
      end

      it 'can get an index of sites' do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end