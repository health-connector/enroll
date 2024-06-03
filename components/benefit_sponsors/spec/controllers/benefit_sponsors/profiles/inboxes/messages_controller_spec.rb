require 'rails_helper'

module BenefitSponsors
  RSpec.describe Inboxes::MessagesController, type: :controller, dbclean: :after_each do

    routes {BenefitSponsors::Engine.routes}
    let!(:security_question)  { FactoryBot.create_default :security_question }

    let!(:site) {FactoryBot.create(:benefit_sponsors_site, :with_owner_exempt_organization, :with_benefit_market, site_key: :cca)}

    let(:organization) {FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site)}
    let!(:active_employer_staff_role) {FactoryBot.create(:benefit_sponsor_employer_staff_role, aasm_state: 'is_active', benefit_sponsor_employer_profile_id: organization.employer_profile.id)}
    let(:inbox) {FactoryBot.create(:benefit_sponsors_inbox, :with_message, recipient: organization.employer_profile)}
    let(:person) {FactoryBot.create(:person, employer_staff_roles: [active_employer_staff_role])}
    let(:user) {FactoryBot.create(:user, :person => person)}

    let(:broker_organization) {FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site)}
    let(:broker_person) { FactoryBot.create(:person, :with_broker_role) }
    let(:broker_user) { FactoryBot.create(:user, person: broker_person) }

    let(:admin_person) {FactoryBot.create(:person)}
    let(:admin_user) {FactoryBot.create(:user, :person => admin_person)}
    let(:hbx_staff_role) {FactoryBot.create(:hbx_staff_role, person: admin_user.person)}


    describe "GET show / DELETE destroy" do
      context "for employer profile" do
        before do
          sign_in user
        end

        context "show message" do
          before do
            get :show, params: { id: organization.employer_profile.id, message_id: inbox.messages.first.id }
          end

          it "should render show template" do
            expect(response).to render_template("show")
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context "delete message" do
          before do
            delete :destroy, params: { id: organization.employer_profile.id, message_id: inbox.messages.first.id }, format: :js
          end

          it "should get a notice" do
            expect(flash[:notice]).to match /Successfully deleted inbox message./
          end
        end

      end

      context "for broker agency profile" do
        before do
          broker_person.broker_role.update_attributes!(benefit_sponsors_broker_agency_profile_id: broker_organization.broker_agency_profile.id)
          @broker_inbox = broker_person.build_inbox
          @broker_inbox.save!
          welcome_subject = "Welcome to #{Settings.site.short_name}"
          welcome_body = "#{Settings.site.short_name} is the #{Settings.aca.state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your health needs and budgets."
          @broker_inbox.messages.create(subject: welcome_subject, body: welcome_body)
          sign_in broker_user
        end

        context "show message" do
          before do
            get :show, params: { id: broker_person.id, message_id: @broker_inbox.messages.first.id }
          end

          it "should render show template" do
            expect(response).to render_template("show")
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context "delete message" do
          before do
            delete :destroy, params: { id: broker_person.id, message_id: @broker_inbox.messages.first.id }, format: :js
          end

          it "should get a notice" do

            expect(flash[:notice]).to match /Successfully deleted inbox message./
          end
        end
      end

      context "for broker agency profile - from Admin login" do
        before do
          broker_person.broker_role.update_attributes!(benefit_sponsors_broker_agency_profile_id: broker_organization.broker_agency_profile.id)
          @broker_inbox = broker_person.build_inbox
          @broker_inbox.save!
          welcome_subject = "Welcome to #{Settings.site.short_name}"
          welcome_body = "#{Settings.site.short_name} is the #{Settings.aca.state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your health needs and budgets."
          @broker_inbox.messages.create(subject: welcome_subject, body: welcome_body)
          sign_in admin_user
        end

        context "show message" do
          before do
            get :show, params: { id: broker_person.id, message_id: @broker_inbox.messages.first.id }
          end

          it "should render show template" do
            expect(response).to render_template("show")
          end

          it "should return http success" do
            expect(response).to have_http_status(:success)
          end
        end

        context "delete message" do
          before do
            delete :destroy, params: { id: broker_person.id, message_id: @broker_inbox.messages.first.id }, format: :js
          end

          it "should get a notice" do
            expect(flash[:notice]).to match /Successfully deleted inbox message./
          end
        end
      end
    end

    context "logged in user has no authorization roles" do
      let(:person) { create(:person) }
      let(:fake_user) { FactoryBot.create(:user, :person => person) }

      context "show message" do
        before do
          sign_in fake_user
          get :show, id: organization.employer_profile.id, message_id: inbox.messages.first.id
        end

        it "errors out with flash message" do
          expect(flash[:error]).to eq('Access not allowed for can_read_inbox?, (Pundit policy)')
        end
      end

      context "delete message" do
        before do
          sign_in fake_user
          delete :destroy, id: organization.employer_profile.id, message_id: inbox.messages.first.id, format: :js
        end

        it "errors out with with flash message" do
          expect(flash[:error]).to eq('Access not allowed for can_read_inbox?, (Pundit policy)')
        end
      end
    end

    context "inactive broker staff logged in" do
      let(:broker_staff_user) { FactoryBot.create(:user, person: broker_staff_person) }
      let(:broker_staff_person) { FactoryBot.create(:person) }
      let(:broker_organization_2) {FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, site: site)}
      let(:broker_agency_profile_2) { broker_organization_2.broker_agency_profile }
      let(:broker_agency_id) { broker_agency_profile_2.id }
      let(:broker_staff) do
        FactoryBot.create(
          :broker_agency_staff_role,
          person: broker_staff_person,
          aasm_state: 'broker_agency_terminated',
          benefit_sponsors_broker_agency_profile_id: broker_agency_id
        )
      end

      context "show message" do
        before do
          sign_in broker_staff_user
          get :show, id: organization.employer_profile.id, message_id: inbox.messages.first.id
        end

        it "errors out with flash message" do
          expect(flash[:error]).to eq('Access not allowed for can_read_inbox?, (Pundit policy)')
        end
      end

      context "delete message" do
        before do
          sign_in broker_staff_user
          delete :destroy, id: organization.employer_profile.id, message_id: inbox.messages.first.id, format: :js
        end

        it "errors out with with flash message" do
          expect(flash[:error]).to eq('Access not allowed for can_read_inbox?, (Pundit policy)')
        end
      end
    end
  end
end
