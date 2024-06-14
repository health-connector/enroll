# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::FamilyMembersController, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let!(:user) { FactoryBot.create(:user) }
  let!(:person) { FactoryBot.create(:person) }
  let!(:family) { FactoryBot.create(:family, :with_primary_family_member, person: person) }

  let(:employee_role) {FactoryBot.create(:employee_role, person: person, employer_profile: abc_profile)}
  let(:census_employee) { create(:census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: abc_profile) }

  before :each do
    allow(user).to receive(:person).and_return person
    allow(person).to receive(:primary_family).and_return family
    allow(employee_role).to receive(:census_employee).and_return census_employee
    allow(controller.request).to receive(:referer).and_return(nil)
  end

  context "logged in user failed authorization for index and new" do
    let(:fake_person) { FactoryBot.create(:person, :with_employee_role) }
    let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
    let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }

    it "redirects to root with flash message" do
      sign_in(fake_user)
      get :new, params: { family_id: family.id }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Access not allowed for family_policy.new?, (Pundit policy)")
    end

    it "redirects to root with flash message" do
      sign_in(fake_user)
      get :index, params: { family_id: family.id }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Access not allowed for family_policy.index?, (Pundit policy)")
    end

  end

  context "logged in user failed authorization for edit and show" do
    shared_examples_for "logged in user has no authorization roles for family_members controller" do |action|
      let(:fake_person) { FactoryBot.create(:person, :with_employee_role) }
      let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
      let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }

      it "redirects to root with flash message" do
        sign_in(fake_user)

        get action, params: {id: family.family_members.last.id}
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Access not allowed for family_policy.#{action}?, (Pundit policy)")
      end
    end

    it_behaves_like 'logged in user has no authorization roles for family_members controller', :edit
    it_behaves_like 'logged in user has no authorization roles for family_members controller', :show
  end

  context "logged in user failed authorization for destroy" do
    let(:fake_person) { FactoryBot.create(:person, :with_employee_role) }
    let(:fake_user) { FactoryBot.create(:user, person: fake_person) }
    let!(:fake_family) { FactoryBot.create(:family, :with_primary_family_member, person: fake_person) }

    it "redirects to root with flash message" do
      sign_in(fake_user)

      delete :destroy, params: {id: family.family_members.last.id}
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Access not allowed for family_policy.destroy?, (Pundit policy)")
    end
  end
end
