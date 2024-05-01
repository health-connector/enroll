# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Exchanges::SecurityQuestionsController, dbclean: :after_each do
  let!(:user) { FactoryGirl.create(:user, :with_hbx_staff_role) }
  let!(:person) { FactoryGirl.create(:person, user: user)}
  let!(:site)                          { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:organization_with_hbx_profile)  { site.owner_organization }
  let(:error_message) {"Security qestions display feature is not enabled. You are not allowed to create, edit, view or delete security questions."}

  before do
    allow_any_instance_of(HbxStaffRole).to receive(:permission).and_return(double(view_admin_tabs: true))
    allow(Settings).to receive_message_chain('aca.security_questions').and_return(false)
    user.person.build_hbx_staff_role(hbx_profile_id: organization_with_hbx_profile.hbx_profile.id)
    user.person.hbx_staff_role.save!
    sign_in(user)
  end

  describe 'GET #index' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end

  describe 'GET #new' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        get :new
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end

  describe 'POST #create' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        post :create, params: {}
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end

  describe 'GET #edit' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        get :edit, id: 'random_id'
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end

  describe 'PATCH #update' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        patch :update, id: 'random_id'
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'security questions feature is disabled' do
      it 'redirects to root with flash message' do
        delete :destroy, id: 'random_id'
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq(error_message)
      end
    end
  end
end
