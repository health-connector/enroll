require 'spec_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"


RSpec.describe BenefitSponsors::ApplicationHelper, type: :helper, dbclean: :after_each do
  include BenefitSponsors::ApplicationHelper

  describe '.profile_unread_messages_count', dbclean: :after_each do
    let(:inbox) { double('inbox', unread_messages: [1], unread_messages_count: 2 )}
    let(:profile) { double('Profile', inbox: inbox)}

    context 'when profile is an instance of BenefitSponsors::Organizations::Profile then' do
      before do
        expect(profile).to receive(:is_a?).and_return(true)
      end
      it { expect(profile_unread_messages_count(profile)).to eq(1) }
    end

    context 'when profile is not an instance of BenefitSponsors::Organizations::Profile then' do
      before do
        expect(profile).to receive(:is_a?).and_return(false)
      end
      it { expect(profile_unread_messages_count(profile)).to eq(2) }
    end

    context 'when there is an error then', dbclean: :after_each do
      let(:site) { FactoryGirl.create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:broker_organization) { FactoryGirl.build(:benefit_sponsors_organizations_general_organization, site: site) }
      let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, organization: broker_organization, market_kind: 'shop', legal_name: 'Legal Name1') }

      it "has the correct number of unread messages" do
        expect(profile_unread_messages_count(broker_agency_profile)).to eq(0)
      end
    end
  end

  describe "add_plan_year_button_business_rule", dbclean: :after_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup renewal application"

    context 'should return false when an active PY no canceled PY' do
      it{ expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq false }
    end

    context 'should return false when a published PY' do
      before do
        renewal_application.update_attributes(:aasm_state => :enrollment_open)
      end
      it {expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq false}
    end

    context 'should return true when with an active initial and canceled renewal PY with renewal start date is greater the initial end on' do
      before do
        renewal_application.update_attributes(:aasm_state => :canceled)
      end
      it {expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq true}
    end

    context 'should return false when with an active initial and termination pending renewal PY' do
      before do
        renewal_application.update_attributes(:aasm_state => :termination_pending)
      end
      it {expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq false}
    end

    context 'should return true when with an inactive initial and termination pending renewal PY' do
      before do
        predecessor_application.update_attributes(:aasm_state => :expired)
        renewal_application.update_attributes(:aasm_state => :termination_pending)
      end
      it {expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq true}
    end

    context 'should return false when BA is_renewal true' do
      before do
        renewal_application.update_attributes(:aasm_state => :enrollment_ineligible)
      end
      it {expect(add_plan_year_button_business_rule(abc_profile.benefit_applications)).to eq false}
    end
  end
end
