# frozen_string_literal: true

require "rails_helper"
require './spec/shared_context/setup_shop_families_enrollments'

describe CheckEmployerBenefitsForEmployee, :dbclean => :after_each do
  include_context "setup shop families enrollments"
  let(:sponsored_benefit_package) { hbx_enrollment.sponsored_benefit_package }
  let(:benefit_application) { sponsored_benefit_package.benefit_application }

  context 'CheckEmployerBenefitsForEmployee' do
    it 'when market kind is shop and enr is passed' do
      context = described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment])
      expect(context.success?).to eq true
    end

    it 'when market kind is ivl and enr is passed' do
      context = described_class.call(market_kind: 'individual', shopping_enrollments: [hbx_enrollment])
      expect(context.success?).to eq true
    end

    context 'sponsored_benefit_package is not shoppable' do
      before :each do
        allow(sponsored_benefit_package).to receive(:shoppable?).and_return(false)
      end

      it 'when application is terminated' do
        allow(benefit_application).to receive(:terminated?).and_return(true)
        context = described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment])
        expect(context.failure?).to eq true
        expect(context.message).to eq "Your employer is no longer offering #{hbx_enrollment.coverage_kind} insurance through #{Settings.site.short_name}. Please contact your employer."
      end

      it 'when application is termination pending' do
        allow(benefit_application).to receive(:termination_pending?).and_return(true)
        context = described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment])
        expect(context.failure?).to eq true
        expect(context.message).to eq "Your employer is no longer offering #{hbx_enrollment.coverage_kind} insurance through #{Settings.site.short_name}.
                                  Please contact your employer or call our Customer Care Center at #{Settings.contact_center.phone_number}."
      end

      it 'when benefit package is not shoppable and application is not terminated.' do
        context = described_class.call(market_kind: 'shop', shopping_enrollments: [hbx_enrollment])
        expect(context.failure?).to eq true
        expect(context.message).to eq "Open enrollment for your employer-sponsored benefits not yet started. Please return on #{hbx_enrollment.sponsored_benefit_package.open_enrollment_start_on.strftime('%m/%d/%Y')} to enroll for coverage."
      end
    end
  end
end