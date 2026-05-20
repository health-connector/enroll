# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvitationsController do
  let(:user) { instance_double("User") }
  let(:invitation_id) { "an invitation id" }
  let(:invitation) { instance_double(Invitation, :may_claim? => unclaimed) }

  describe "GET claim" do

    before(:each) do
      sign_in(user)
      allow(Invitation).to receive(:find).with(invitation_id).and_return(invitation)
    end

    describe "with an already claimed invitation" do
      let(:unclaimed) { false }

      it "should redirect back to the welcome page with an error" do
        get :claim, params: {:id => invitation_id}
        expect(response).to redirect_to(root_url)
        expect(flash[:error]).to eq "Invalid invitation."
      end
    end

    describe "with a valid, unclaimed invitation" do
      let(:unclaimed) { true }

      it "should claim the invitation" do
        expect(invitation).to receive(:claim_invitation!).with(user, controller) do |_u, c|
          c.redirect_to root_url
        end
        get :claim, params: {:id => invitation_id}
        expect(response).to redirect_to(root_url)
      end
    end

  end

  describe "GET claim when not logged in (require_login_and_allow_new_account)" do
    before(:each) do
      sign_out :user
    end

    it "stores the claim URL in session[:portal]" do
      get :claim, params: { id: invitation_id }
      expect(session[:portal]).to eq claim_invitation_url(id: invitation_id)
    end

    it "redirects to the sign up page with invitation_id as a query param" do
      get :claim, params: { id: invitation_id }
      expect(response).to redirect_to(new_user_registration_url(invitation_id: invitation_id))
    end

    it "does not attempt to find the invitation" do
      expect(Invitation).not_to receive(:find)
      get :claim, params: { id: invitation_id }
    end
  end
end
