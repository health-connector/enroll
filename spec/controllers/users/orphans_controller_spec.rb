# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::OrphansController, dbclean: :after_each do
  let(:admin_person) { FactoryBot.create(:person, :with_hbx_staff_role) }
  let(:admin_user) {FactoryBot.create(:user, :with_hbx_staff_role, :person => admin_person)}
  let(:admin_permission) { FactoryBot.create(:permission, :super_admin) }

  let(:consumer_person) { FactoryBot.create(:person, :with_consumer_role, :with_family) }
  let(:consumer_user) {FactoryBot.create(:user, :person => consumer_person)}

  let(:orphan_user) { FactoryBot.create(:user) }

  context "show" do
    it "should respond successfully to users with correct permissions" do
      admin_permission.update_attributes!(can_access_user_account_tab: true)
      admin_person.hbx_staff_role.update_attributes(permission_id: admin_permission.id)

      sign_in(admin_user)
      get :show, params: { id: orphan_user.id}, xhr: true
      expect(response).to have_http_status(:success)
    end

    it "should redirect users without permission" do
      sign_in(consumer_user)
      get :show, params: { id: orphan_user.id}, xhr: true
      expect(response).to have_http_status(:forbidden)
    end
  end
end
