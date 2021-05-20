require 'rails_helper'

RSpec.describe SessionTimeoutController, :type => :controller do
  describe "check_time_until_logout" do
    let(:user) { FactoryGirl.create :user}

    context "when time_left <= 0" do
      let(:session) { {"last_request_at" => Devise.timeout_in + 100.seconds }}

      before :each do
        sign_in user
        allow(controller).to receive(:user_session).and_return session
        get :check_time_until_logout, format: :js      
      end

      it "should have @time_left <= 0" do
        expect(response).to render_template("devise/sessions/sign_out_user")
      end
    end

    context "when time_left > 0" do
       let(:session) { {"last_request_at" => Time.now - 3 }}

      before do
        sign_in user
        allow(controller).to receive(:user_session).and_return session
        get :check_time_until_logout, format: :js
      end

      it "returns http success" do
        expect(response).to render_template('devise/sessions/session_expiration_warning')
      end
    end
  end
end
