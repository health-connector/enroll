# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Exchanges::AnnouncementsController do
  let(:announcement) { FactoryBot.create(:announcement) }
  let(:user_no_person) { FactoryBot.create(:user) }
  let(:user) { FactoryBot.create(:user) }
  let(:person) { FactoryBot.create(:person, user: user) }
  let(:hbx_staff_role) { FactoryBot.create(:hbx_staff_role, person: person) }
  let(:unauthorized_user) { FactoryBot.create(:user, person: unauthorized_person) }
  let(:unauthorized_person) { FactoryBot.create(:person) } # Person without any special roles

  describe "GET index" do
    it "should redirect when login without hbx_staff" do
      sign_in user_no_person
      get :index
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq "You must be an HBX staff member"
    end

    context "with hbx_staff" do
      context "without filter" do
        before :each do
          allow(user).to receive(:has_hbx_staff_role?).and_return true
          allow_any_instance_of(AnnouncementPolicy).to receive(:index?).and_return(true)
          sign_in user
          get :index
        end

        it "renders index" do
          expect(response).to have_http_status(:success)
          expect(response).to render_template("exchanges/announcements/index")
        end

        it "get current announcements" do
          expect(assigns(:announcements)).to eq Announcement.current
        end
      end

      context "with filter" do
        before :each do
          allow(user).to receive(:has_hbx_staff_role?).and_return true
          allow_any_instance_of(AnnouncementPolicy).to receive(:index?).and_return(true)
          sign_in user
          get :index, params: { filter: 'all' }
        end

        it "get all announcements" do
          expect(assigns(:announcements)).to eq Announcement.all
        end
      end
    end
  end

  describe "POST create" do
    let(:announcement_params) { {announcement: {content: 'msg', start_date: '2016-3-1', end_date: TimeKeeper.date_of_record.strftime('%Y/%m/%d'), audiences: ['Employer']}} }

    it "should redirect when login without hbx_staff" do
      sign_in user_no_person
      post :create, params: announcement_params
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq "You must be an HBX staff member"
    end

    context "with hbx_staff" do
      before :each do
        allow(user).to receive(:has_hbx_staff_role?).and_return true
        allow_any_instance_of(AnnouncementPolicy).to receive(:create?).and_return(true)
        allow_any_instance_of(HbxProfilePolicy).to receive(:modify_admin_tabs?).and_return(true)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true))
        sign_in user
        post :create, params: announcement_params
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
      end

      it "should get successful notice" do
        expect(flash[:notice]).to eq "Create Announcement Successful."
      end
    end

    context "with hbx_readonly" do
      before :each do
        allow(user).to receive(:has_hbx_staff_role?).and_return true
        allow_any_instance_of(AnnouncementPolicy).to receive(:create?).and_return(false)
        allow_any_instance_of(HbxProfilePolicy).to receive(:modify_admin_tabs?).and_return(false)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: false))
        sign_in user
        post :create, params: announcement_params
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
      end

      it "should get an error" do
        expect(flash[:error]).to match(/Access not allowed/)
      end
    end

    context "with invalid params" do
      let(:invalid_announcement_params) { {announcement: {content: 'msg', start_date: '2016-3-1', end_date: '2016-10-1'}} }
      before :each do
        allow(user).to receive(:has_hbx_staff_role?).and_return true
        allow_any_instance_of(AnnouncementPolicy).to receive(:create?).and_return(true)
        allow_any_instance_of(HbxProfilePolicy).to receive(:modify_admin_tabs?).and_return(true)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true))
        sign_in user
        post :create, params: invalid_announcement_params
      end

      it "should render template" do
        expect(response).to render_template("index")
      end

      it "should get announcements" do
        expect(assigns(:announcements)).to eq Announcement.current
      end
    end
  end

  describe "DELETE destroy" do
    it "should redirect when login without hbx_staff" do
      sign_in user
      delete :destroy, params: { id: announcement.id }
      expect(response).to have_http_status(:redirect)
      expect(flash[:error]).to eq "You must be an HBX staff member"
    end

    context "with hbx_staff" do
      before :each do
        allow(user).to receive(:has_hbx_staff_role?).and_return true
        allow_any_instance_of(AnnouncementPolicy).to receive(:destroy?).and_return(true)
        allow_any_instance_of(HbxProfilePolicy).to receive(:modify_admin_tabs?).and_return(true)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: true))
        sign_in user
        delete :destroy, params: { id: announcement.id }
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
      end

      it "should get successful notice" do
        expect(flash[:notice]).to eq "Destroy Announcement Successful."
      end
    end

    context "with hbx_readonly" do
      before :each do
        allow(user).to receive(:has_hbx_staff_role?).and_return true
        allow_any_instance_of(AnnouncementPolicy).to receive(:destroy?).and_return(false)
        allow_any_instance_of(HbxProfilePolicy).to receive(:modify_admin_tabs?).and_return(false)
        allow(hbx_staff_role).to receive(:permission).and_return(double('Permission', modify_admin_tabs: false))
        sign_in user
        delete :destroy, params: { id: announcement.id }
      end

      it "should redirect" do
        expect(response).to have_http_status(:redirect)
      end

      it "should get an error" do
        expect(flash[:error]).to match(/Access not allowed/)
      end
    end
  end

  describe "GET dismiss" do
    it "should update session" do
      allow_any_instance_of(AnnouncementPolicy).to receive(:dismiss?).and_return(true)
      sign_in user
      get :dismiss, params: { content: "hello announcement" }
      expect(session[:dismiss_announcements]).to eq ["hello announcement"].to_json
    end
  end

  describe "authorization failure" do
    context "when user does not have authorization for index action" do
      it "returns a failure response" do
        sign_in unauthorized_user
        get :index
        expect(flash[:error]).to eq("You must be an HBX staff member")
      end
    end

    context "when user does not have authorization for create action" do
      let(:announcement_params) { {announcement: {content: 'msg', start_date: '2016-3-1', end_date: TimeKeeper.date_of_record.strftime('%Y/%m/%d'), audiences: ['Employer']}} }

      it "returns a failure response" do
        sign_in unauthorized_user
        post :create, params: announcement_params
        expect(flash[:error]).to eq("You must be an HBX staff member")
      end
    end

    context "when user does not have authorization for destroy action" do
      it "returns a failure response" do
        sign_in unauthorized_user
        delete :destroy, params: { id: announcement.id }
        expect(flash[:error]).to eq("You must be an HBX staff member")
      end
    end

    context "when user does not have authorization for dismiss action" do
      it "returns a failure response" do
        sign_in unauthorized_user
        get :dismiss, params: { content: "hello announcement" }
        expect(flash[:error]).to eq("Access not allowed for announcement_policy.dismiss?, (Pundit policy)")
      end
    end
  end
end
