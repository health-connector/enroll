# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe HireAndAssignCurrentUserBrokerAgency, :dbclean => :after_each do
  include_context "setup shop families enrollments"
  let(:broker_agency_profile) { FactoryBot.create(:broker_agency_profile) }
  let(:broker_role) { FactoryBot.create(:broker_role, :aasm_state => 'active', broker_agency_profile: broker_agency_profile) }
  let(:person) { broker_role.person }
  let(:user) { FactoryBot.create(:user, person: person, roles: ['broker']) }

  context 'with invalid params' do
    it 'when current user is nil' do
      context = described_class.call(current_user: nil, primary_family: family, shopping_enrollments: [hbx_enrollment])
      expect(context.success?).to eq true
    end

    it 'when family is not passed' do
      context = described_class.call(current_user: user, primary_family: nil, shopping_enrollments: [hbx_enrollment])
      expect(context.success?).to eq true
    end

    it 'when enr is not passed' do
      context = described_class.call(current_user: user, primary_family: family, shopping_enrollments: [])
      expect(context.success?).to eq true
    end
  end

  context 'with valid params' do
    it 'should assigning the broker role and agency ids' do
      described_class.call(current_user: user, primary_family: family, shopping_enrollments: [hbx_enrollment])
      expect(hbx_enrollment.writing_agent_id).to eq broker_role.id
      expect(hbx_enrollment.broker_agency_profile_id).to eq broker_role.broker_agency_profile_id
    end
  end
end