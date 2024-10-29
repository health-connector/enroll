# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, dbclean: :after_each do

  context "create" do
    let(:curam_user){ double("CuramUser") }
    let(:email){ "test@example.com" }
    let(:password){ "aA1!aA1!aA1!"}

    context "when the email is in the black list" do

      before(:each) do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        allow(CuramUser).to receive(:match_unique_login).with(email).and_return([curam_user])
      end

      it "should redirect to saml recovery page if user matches" do
        post :create, params: { user: { oim_id: email, password: password, password_confirmation: password } }
        expect(response).to be_successful
        expect(flash[:alert]).to eq "An account with this username ( #{email} ) already exists. <a href=\"#{SamlInformation.account_recovery_url}\">Click here</a> if you've forgotten your password."
      end
    end

    context "when the email is not the black list" do

      before(:each) do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        allow(CuramUser).to receive(:match_unique_login).with("test@example.com").and_return([])
      end

      it "should not redirect to saml recovery page if user matches" do
        post :create, params: { user: { oim_id: "test@example.com", password: password, password_confirmation: password } }
        expect(response).not_to redirect_to(new_user_registration_path)
      end

    end

    context "account without person" do
      let(:email) { "devise@test.com" }
      let!(:user) { FactoryBot.create(:user, email: email, oim_id: email) }

      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
      end

      it "should complete sign up and redirect" do
        post :create, params: { user: { oim_id: email, password: password, password_confirmation: password } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "account with person" do
      let(:email) { "devisepersoned@test.com"}
      let(:user) { FactoryBot.create(:user, email: email, person: person, oim_id: email) }
      let(:person) { FactoryBot.create(:person) }

      before do
        user.save!
        @request.env["devise.mapping"] = Devise.mappings[:user]
      end

      it "should re-render the page" do
        post :create, params: { user: { oim_id: email, password: password, password_confirmation: password } }
        expect(response).to be_successful
        expect(response).not_to redirect_to(root_path)
      end
    end

    context "with captcha enabled" do

      let(:email) { "test@example.com"}
      let(:user) { FactoryBot.create(:user, email: email, person: person, oim_id: email) }
      let(:person) { FactoryBot.create(:person) }
      let(:recaptcha_token) {''}

      before do
        user.save!
        @request.env["devise.mapping"] = Devise.mappings[:user]
      end
      context "with valid captcha request" do
        before do
          allow(controller).to receive(:handle_recaptcha).and_return(true)
        end

        it "should be a success" do
          expect(response).to be_successful
        end
      end

      context "with invalid captcha request" do

        before :each do
          allow(controller).to receive(:handle_recaptcha).and_return(false)
          post :create, params: { user: { oim_id: email, password: password, password_confirmation: password } }
        end

        it "should render an error" do
          expect(response).to_not be_successful
        end
      end
    end
  end
end
