# frozen_string_literal: true

require 'spec_helper'

module BenefitSponsors
  RSpec.describe Serializers::OrganizationSerializer do
    describe '#is_general_organization?' do
      let(:organization) { double('organization') }
      subject { described_class.new(organization).is_general_organization? }

      context 'when organization is a GeneralOrganization' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
          allow(organization).to receive(:is_a?).with(BenefitSponsors::Organizations::GeneralOrganization).and_return(true)
        end

        it { is_expected.to be_truthy }
      end

      context 'when organization is an ExemptOrganization' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
          allow(organization).to receive(:is_a?).with(BenefitSponsors::Organizations::ExemptOrganization).and_return(true)
        end

        it { is_expected.to be_truthy }
      end

      context 'when organization is another type' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
        end

        it { is_expected.to be_falsey }
      end
    end

    describe 'fein attribute inclusion' do
      let(:organization) { double('organization') }
      let(:serializer) { described_class.new(organization) }

      context 'when organization is a GeneralOrganization' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
          allow(organization).to receive(:is_a?).with(BenefitSponsors::Organizations::GeneralOrganization).and_return(true)
        end

        it 'includes fein in the serialized attributes' do
          expect(serializer.is_general_organization?).to be_truthy
        end
      end

      context 'when organization is an ExemptOrganization' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
          allow(organization).to receive(:is_a?).with(BenefitSponsors::Organizations::ExemptOrganization).and_return(true)
        end

        it 'includes fein in the serialized attributes' do
          expect(serializer.is_general_organization?).to be_truthy
        end
      end

      context 'when organization is another type' do
        before do
          allow(organization).to receive(:is_a?).and_return(false)
        end

        it 'excludes fein from the serialized attributes' do
          expect(serializer.is_general_organization?).to be_falsey
        end
      end
    end
  end
end
