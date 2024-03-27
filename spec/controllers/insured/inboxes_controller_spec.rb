# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::InboxesController, :type => :controller, :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:hbx_profile) { FactoryGirl.create(:hbx_profile)}
  let(:person) { FactoryGirl.create(:person, :with_employee_role)}
  let(:employee_role) {FactoryGirl.create(:employee_role, person: person, employer_profile: abc_profile, census_employee: census_employee)}
  let(:user) { FactoryGirl.create(:user, person: person) }
  let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person) }
  let(:census_employee) { FactoryGirl.create(:census_employee, :with_enrolled_census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: abc_profile) }

  # Need to generate an actual inbox for the authorization with InboxPolicy
  let(:inbox) { FactoryGirl.create(:inbox, :with_message, recipient: person) }
  let(:message) { inbox.messages.first }

  # This is used for all CREATE methods
  let(:valid_params) { {'subject' => 'test', 'body' => 'test', 'sender_id' => '558b63ef4741542b64290000', 'from' => 'HBXAdmin', 'to' => 'Acme Inc.'} }

  before do
    allow(person).to receive(:user).and_return(user)
    allow(employee_role).to receive(:census_employee).and_return census_employee
    allow(person).to receive(:primary_family).and_return family
  end

  context 'employee', dbclean: :after_each do
    context 'with permissions' do
      before do
        sign_in(user)
      end

      describe 'GET new / post CREATE' do
        it 'will render :new' do
          xhr :get, :new, :id => person.id, profile_id: hbx_profile.id, to: "test", format: :js

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to render_template('new')
          expect(response).to have_http_status(:success)
        end

        it 'will create a new message' do
          post :create, id: person.id, profile_id: hbx_profile.id, message: valid_params

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to have_http_status(:redirect)
        end
      end

      describe 'GET show / DELETE destroy' do
        it 'will show specific message' do
          get :show, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to render_template('show')
          expect(response).to have_http_status(:success)
        end

        it 'will delete a message' do
          xhr :delete, :destroy, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'without permissions', dbclean: :after_each do
      let(:fake_person) { FactoryGirl.create(:person, :with_employee_role) }
      let(:fake_user) { FactoryGirl.create(:user, person: fake_person) }
      let!(:fake_family) { FactoryGirl.create(:family, :with_primary_family_member, person: fake_person) }

      before do
        sign_in(fake_user)
      end

      describe 'GET new / post CREATE' do
        it 'will not render :new' do
          xhr :get, :new, :id => person.id, profile_id: hbx_profile.id, to: "test", format: :js

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(403)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end

        it 'will not create a new message' do
          post :create, id: person.id, profile_id: hbx_profile.id, message: valid_params

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end
      end

      describe 'GET show / DELETE destroy' do
        it 'will not show specific message' do
          get :show, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end

        it 'will not delete a message' do
          xhr :delete, :destroy, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(403)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end
      end
    end
  end

  context 'admin', dbclean: :after_each do
    let!(:admin_person) { FactoryGirl.create(:person, :with_hbx_staff_role) }
    let!(:admin_user) { FactoryGirl.create(:user, :with_hbx_staff_role, person: admin_person) }

    context 'with permissions' do
      let!(:permission) { FactoryGirl.create(:permission, :super_admin) }
      let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: permission.id) }

      before do
        sign_in(admin_user)
      end

      describe 'GET new / post CREATE' do
        it 'will render :new' do
          xhr :get, :new, :id => person.id, profile_id: hbx_profile.id, to: "test", format: :js

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to render_template('new')
          expect(response).to have_http_status(:success)
        end

        it 'will create a new message' do
          post :create, id: person.id, profile_id: hbx_profile.id, message: valid_params

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to have_http_status(:redirect)
          expect(flash[:notice]).to eq("Successfully sent message.")
        end
      end

      describe 'GET show / DELETE destroy' do
        it 'will show specific message' do
          get :show, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to render_template('show')
          expect(response).to have_http_status(:success)
        end

        it 'will delete a message' do
          xhr :delete, :destroy, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_truthy
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'without permissions' do
      let!(:invalid_permission) { FactoryGirl.create(:permission, :developer) }
      let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: invalid_permission.id) }

      before do
        sign_in(admin_user)
      end

      describe 'GET new / post CREATE' do
        it 'will not render :new' do
          xhr :get, :new, :id => person.id, profile_id: hbx_profile.id, to: "test", format: :js

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(403)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end

        it 'will not create a new message' do
          post :create, id: person.id, profile_id: hbx_profile.id, message: valid_params

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end
      end

      describe 'GET show / DELETE destroy' do
        it 'will not show specific message' do
          get :show, id: person.id, message_id: message.id, xhr: true, format: :js

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(403)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end

        it 'will not delete a message' do
          xhr :delete, :destroy, id: person.id, message_id: message.id

          expect(assigns(:inbox_provider).present?).to be_falsey
          expect(response).to have_http_status(403)
          expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
        end
      end
    end
  end

  # context 'broker', dbclean: :after_each do
  #   let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: 'shop', legal_name: 'Legal Name1', assigned_site: site) }
  #   let(:writing_agent) { FactoryGirl.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id) }
  #   let!(:broker_user) {FactoryGirl.create(:user, :person => writing_agent.person, roles: ['broker_role', 'broker_agency_staff_role'])}
  #   let!(:broker_agency_account) { FactoryGirl.create(:benefit_sponsors_accounts_broker_agency_account, benefit_sponsorship: benefit_sponsorship, broker_agency_profile: broker_agency_profile) }
  #
  #   context 'associated with the family' do
  #     before do
  #       sign_in(broker_user)
  #     end
  #
  #     describe 'GET new / post CREATE' do
  #       it 'will render :new' do
  #         xhr :get, :new, :id => person.id, profile_id: hbx_profile.id, to: "test", format: :js
  #
  #         expect(assigns(:inbox_provider).present?).to be_truthy
  #         expect(response).to render_template('new')
  #         expect(response).to have_http_status(:success)
  #       end
  #
  #       it 'will create a new message' do
  #         post :create, id: person.id, profile_id: hbx_profile.id, message: valid_params
  #
  #         expect(assigns(:inbox_provider).present?).to be_truthy
  #         expect(response).to have_http_status(:redirect)
  #         expect(flash[:notice]).to eq("Successfully sent message.")
  #       end
  #     end
  #
  #     describe 'GET show / DELETE destroy' do
  #       it 'will show specific message' do
  #         get :show, id: person.id, message_id: message.id
  #
  #         expect(assigns(:inbox_provider).present?).to be_truthy
  #         expect(response).to render_template('show')
  #         expect(response).to have_http_status(:success)
  #       end
  #
  #       it 'will delete a message' do
  #         xhr :delete, :destroy, id: person.id, message_id: message.id
  #
  #         expect(assigns(:inbox_provider).present?).to be_truthy
  #         expect(response).to have_http_status(:success)
  #       end
  #     end
  #   end
  #
  #   context 'without permissions/not hired by family', dbclean: :after_each do
  #     let(:user2) { FactoryGirl.create(:user, person: person2) }
  #     let!(:person2) { FactoryGirl.create(:person) }
  #     let!(:family2) { FactoryGirl.create(:family, :with_primary_family_member, person: person2) }
  #
  #     before do
  #       sign_in(broker_user)
  #     end
  #
  #     describe 'GET new / post CREATE' do
  #       it 'will not render :new' do
  #         xhr :get, :new, :id => person2.id, profile_id: hbx_profile.id, to: "test", format: :js
  #
  #         expect(assigns(:inbox_provider).present?).to be_falsey
  #         expect(response).to have_http_status(403)
  #         expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
  #       end
  #
  #       it 'will not create a new message' do
  #         post :create, id: person2.id, profile_id: hbx_profile.id, message: valid_params
  #
  #         expect(assigns(:inbox_provider).present?).to be_falsey
  #         expect(response).to have_http_status(:redirect)
  #         expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
  #       end
  #     end
  #
  #     describe 'GET show / DELETE destroy' do
  #       it 'will not show specific message' do
  #         get :show, id: person2.id, message_id: message.id
  #
  #         expect(assigns(:inbox_provider).present?).to be_falsey
  #         expect(response).to have_http_status(:redirect)
  #         expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
  #       end
  #
  #       it 'will not delete a message' do
  #         xhr :delete, :destroy, id: person2.id, message_id: message.id
  #
  #         expect(assigns(:inbox_provider).present?).to be_falsey
  #         expect(response).to have_http_status(403)
  #         expect(flash[:error]).to eq("Access not allowed for family_policy.show?, (Pundit policy)")
  #       end
  #     end
  #   end
  # end
end
