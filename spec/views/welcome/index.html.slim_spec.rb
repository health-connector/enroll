# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "welcome/index.html.slim", :type => :view, dbclean: :after_each  do
  let(:user) { FactoryBot.create(:user, oim_id: "test@enroll.com") }

  unless Settings.site.key == :cca
    describe "a signed in user" do
      before :each do
        sign_in user
      end
      it "should has current_user oim_id" do
        render
        expect(rendered).to match(/#{user.oim_id}/)
        expect(rendered).not_to match(/Broker Registration/)
      end
    end
  end

  describe "not signed in user" do
    context "with disabled IVL market" do
      before do
        allow(view).to receive(:individual_market_is_enabled?).and_return(false)
        render
      end
      it "does not show the Consumer portal links" do
        expect(rendered).not_to have_link('Consumer/Family Portal')
      end
      it "does not show the Assisted consumer portal link" do
        expect(rendered).not_to have_link('Assisted Consumer/Family Portal')
      end
    end
  end
end
