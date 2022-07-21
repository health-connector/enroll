# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe FindEnrollment, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context 'should not assign context' do
    it 'when hbx_enrollment id is not passed' do
      context = described_class.call
      expect(context.failure?).to eq true
      expect(context.message).to eq 'no hbx enrollment found for given id'
    end

    it 'when invalid hbx_enrollment id is not passed' do
      context = described_class.call(hbx_enrollment_id: '723982')
      expect(context.failure?).to eq true
      expect(context.message).to eq 'no hbx enrollment found for given id'
    end
  end

  context 'should assign context' do
    it 'when passed hbx_enrollment_id' do
      context = described_class.call(hbx_enrollment_id: hbx_enrollment.id)
      expect(context.hbx_enrollment).to eq hbx_enrollment
    end

    it 'when passed enrollment_id' do
      context = described_class.call(shop_attributes: {enrollment_id: hbx_enrollment.id})
      expect(context.hbx_enrollment).to eq hbx_enrollment
    end

    it 'when passed params id' do
      context = described_class.call(params: {id: hbx_enrollment.id})
      expect(context.hbx_enrollment).to eq hbx_enrollment
    end

    it 'when passed params enrollment_id' do
      context = described_class.call(params: {enrollment_id: hbx_enrollment.id})
      expect(context.hbx_enrollment).to eq hbx_enrollment
    end
  end
end