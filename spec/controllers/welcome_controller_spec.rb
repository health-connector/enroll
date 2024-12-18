# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WelcomeController, :type => :controller do
  describe "GET index" do
    shared_examples "welcome" do
      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "renders welcome index" do
        expect(response).to render_template("index")
      end

      it "has Cookie attributes" do
        expect(response.headers["Set-Cookie"]).to match(/SameSite=Strict/)
        expect(response.headers["Set-Cookie"]).to match(/HttpOnly/)
        expect(response.headers["Strict-Transport-Security"]).to match(/max-age=31536000; includeSubDomains; preload/)
      end
    end

    context "when not signed in" do
      before do
        sign_in nil
        get :index
      end

      include_examples "welcome"
    end

    context "when signed in" do
      before do
        sign_in
        get :index
      end

      include_examples "welcome"
    end

    it "should return to a http status success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST show_hints" do
    let(:user) { FactoryBot.build(:user) }
    it "should return to a http status success" do
      sign_in user
      post "show_hints", xhr: true, :format => "js"
      expect(response).to have_http_status(:success)
    end
  end
end

describe WelcomeController, "visiting #index:
  - as a non-logged in user
  - using a non-english preferred language (ko)
", :type => :controller do

  it "returns http success" do
    @request.headers["HTTP_ACCEPT_LANGUAGE"] = "ko"
    get :index
    expect(response).to have_http_status(:success)
  end
end
