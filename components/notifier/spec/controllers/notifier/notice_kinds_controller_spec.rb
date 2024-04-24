# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifier::NoticeKindsController, type: :controller do
  describe 'GET #download_notices' do
    let(:person) { FactoryBot.create(:person) }
    let(:user) { FactoryBot.create(:user, :person => person) }
    before do
      allow(user).to receive(:has_hbx_staff_role?).and_return(true)
      sign_in(user)
      routes.draw { get 'download_notices' => 'notifier/notice_kinds#download_notices' }
    end

    it "sends a file" do
      get :download_notices

      expect(response.code).to eq("200")
      expect(response.header['Content-Type']).to include 'text/csv'
    end
  end
end
