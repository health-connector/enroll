require 'rails_helper'

module BenefitSponsors
  RSpec.describe EmployerProfilePolicy, dbclean: :after_each do
    let!(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:profile) { organization.employer_profile }
    let(:policy) { BenefitSponsors::EmployerProfilePolicy.new(user, profile) }
    
    context 'person with no roles' do
      let(:person) { FactoryGirl.create(:person) }
      let(:user) { FactoryGirl.create(:user, person:person) }

      shared_examples_for "should not permit for invalid user" do |policy_type|
        it "should not permit" do
          expect(policy.send(policy_type)).to be false
        end
      end

      it_behaves_like "should not permit for invalid user", :show?
      it_behaves_like "should not permit for invalid user", :coverage_reports?
      it_behaves_like "should not permit for invalid user", :updateable?

    end

    context 'person has employer staff role but not for this employer' do
      let(:person) { FactoryGirl.create(:person, :with_employer_staff_role) }
      let(:user) { FactoryGirl.create(:user, person: person) }

      shared_examples_for "should not permit for person with invalid employer staff role" do |policy_type|
        it "should not permit" do
          expect(policy.send(policy_type)).to be false
        end
      end

      it_behaves_like "should not permit for person with invalid employer staff role", :show?
      it_behaves_like "should not permit for person with invalid employer staff role", :coverage_reports?
      it_behaves_like "should not permit for person with invalid employer staff role", :updateable?

    end

    context 'person has employer staff role for this employer' do
      let(:person) { FactoryGirl.create(:person, :with_employer_staff_role, benefit_sponsor_employer_profile_id: profile.id )}
      let(:user) { FactoryGirl.create(:user, person: person) }

      shared_examples_for "permits person with valid employer staff role" do |policy_type|
        it "permits if role is active" do
          expect(policy.send(policy_type)).to be true
        end

        it "does not permit if role is closed" do
          person.employer_staff_roles.first.close_role!
          expect(policy.send(policy_type)).to be false
        end
      end

      it_behaves_like "permits person with valid employer staff role", :show?
      it_behaves_like "permits person with valid employer staff role", :coverage_reports?
      it_behaves_like "permits person with valid employer staff role", :updateable?

    end

    context 'person with HBX admin role' do
      let(:person) { FactoryGirl.create(:person) }
      let(:user) { FactoryGirl.create(:user, :with_hbx_staff_role, person: person) }
      let(:hbx_staff_role) { HbxStaffRole.new(person: user.person) }
      
      before :each do
        allow(hbx_staff_role).to receive_message_chain(:permission, :modify_employer).and_return true
        allow(hbx_staff_role).to receive_message_chain(:permission, :list_enrollments).and_return true
        user.person.hbx_staff_role = hbx_staff_role 
      end

      shared_examples_for "permits HBX admin" do |policy_type|
        it "permits" do
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like "permits HBX admin", :show?
      it_behaves_like "permits HBX admin", :coverage_reports?
      it_behaves_like "permits HBX admin", :updateable?

    end

    context "person has broker role" do
      let(:person) { FactoryGirl.create(:person, :with_broker_role) }
      let(:user) { FactoryGirl.create(:user, person: person) }
      let!(:broker_agency_account) {FactoryGirl.build(:benefit_sponsors_accounts_broker_agency_account, writing_agent: person.broker_role) }
      let!(:sponsor) { profile.add_benefit_sponsorship }

      shared_examples_for "permits person with broker role" do |policy_type|
        it "permits broker if assigned to employer" do
          sponsor.broker_agency_accounts << broker_agency_account
          sponsor.organization.save
          expect(policy.send(policy_type)).to be true
        end

        it "does not permit broker if not assigned to employer" do
          expect(policy.send(policy_type)).to be false
        end
      end

      it_behaves_like "permits person with broker role", :show?
      it_behaves_like "permits person with broker role", :coverage_reports?
      it_behaves_like "permits person with broker role", :updateable?

    end
  end
end
