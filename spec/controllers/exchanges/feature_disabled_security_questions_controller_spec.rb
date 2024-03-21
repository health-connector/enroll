# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Exchanges::SecurityQuestionsController, dbclean: :after_each do
  let(:person) { FactoryGirl.create(:person) }
  let(:user) { FactoryGirl.create(:user, person: person) }
  let(:error_message) {"Security qestions display feature is not enabled. You are not allowed to create, edit, view or delete security questions."}

  before do
    EnrollRegistry[:security_questions_display].feature.stub(:is_enabled).and_return(false)
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
