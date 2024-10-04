# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::PasswordsController, dbclean: :after_each do
  include L10nHelper

  let(:curam_user) { double("CuramUser") }
  let(:email) { "test@example.com" }
  let(:user) { FactoryBot.create(:user, email: email) }
  let(:incorrect_email) { "incorrect@email.com" }

  context "create" do
    before(:each) do
      allow(EnrollRegistry[:generic_forgot_password_text].feature).to receive(:is_enabled).and_return(false)
      @request.env["devise.mapping"] = Devise.mappings[:user]
      allow(CuramUser).to receive(:match_unique_login).with(email).and_return([curam_user])
      user.update_attributes!(email: email)
    end

    it "redirects to new_user_password_path" do
      post :create, params: { user: { email: email } }
      expect(response).to have_http_status(302)
    end

    context "generic forgot password text feature is disabled" do
      let(:email2) {"test2@test.com"}
      let(:user2) { FactoryBot.create :user, email: email2}

      before do
        allow(EnrollRegistry[:generic_forgot_password_text].feature).to receive(:is_enabled).and_return(false)
      end

      it "returns no flash notice when user is not found" do
        post :create, params: { user: { email: incorrect_email } }
        expect(flash[:notice]).to be_nil
      end

      it "returns the default flash notice when user is found" do
        user2.save
        post :create, params: { user: { email: email2} }
        expect(flash[:notice]).to eq l10n('devise.passwords.send_instructions')
      end
    end

    context "generic forgot password text feature is enabled" do
      before do
        allow(EnrollRegistry[:generic_forgot_password_text].feature).to receive(:is_enabled).and_return(true)
      end

      it "returns a generic flash notice when user is not found" do
        post :create, params: { user: { email: incorrect_email} }
        expect(flash[:notice]).to eq l10n('devise.passwords.new.generic_forgot_password_text')
      end

      it "returns a generic flash notice when user is found" do
        post :create, params: { user: { email: email} }
        expect(flash[:notice]).to eq l10n('devise.passwords.new.generic_forgot_password_text')
      end
    end

    context "employee user submits forgot password" do
      let(:user) { FactoryBot.create(:user, person: person)}
      let(:person) {FactoryBot.create(:person, :with_employee_role) }

      before :each do
        sign_in user
      end

      it "should not delete security question for employees" do
        expect(user.security_question_responses.count).to eq(3)
        post :create, params: { user: { email: user.email} }
        user.reload
        expect(user.security_question_responses.count).to eq(3)
      end
    end
  end
end
