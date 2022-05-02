# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe BuildMemberGroup, :dbclean => :after_each do
  include_context "setup shop families enrollments"
  let(:product) { FactoryGirl.create(:benefit_markets_products_health_products_health_product, :with_issuer_profile)}

  context 'should not assign member_group' do
    it 'when product is not passed' do
      context = described_class.call(hbx_enrollment: hbx_enrollment, product: nil)
      expect(context.member_group).to eq nil
    end

    it 'when hbx_enrollment is not passed' do
      context = described_class.call(hbx_enrollment: nil, product: product)
      expect(context.member_group).to eq nil
    end

    it 'when hbx_enrollment and product is not passed' do
      context = described_class.call(hbx_enrollment: nil, product: nil)
      expect(context.member_group).to eq nil
    end
  end

  context 'should assign member_group' do

    it 'when params are passed' do
      context = described_class.call(hbx_enrollment: hbx_enrollment, product: product)
      expect(context.member_group).not_to eq nil
    end
  end
end