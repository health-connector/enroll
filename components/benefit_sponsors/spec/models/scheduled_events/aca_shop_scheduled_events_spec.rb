# frozen_string_literal: true

require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::ScheduledEvents::AcaShopScheduledEvents, dbclean: :after_each do
  let(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:current_effective_date) { TimeKeeper.date_of_record.next_month.beginning_of_month }
  let(:new_date) { Date.new(TimeKeeper.date_of_record.year, 3, 26) }
  let(:scheduled_event) { described_class.new(new_date) }

  describe '#initialize' do
    let(:logger) { instance_double(Logger) }

    before do
      allow(Logger).to receive(:new).and_return(logger)
      allow(logger).to receive(:info)
    end

    it 'sets the new_date' do
      expect(scheduled_event.new_date).to eq new_date
    end

    it 'calls initialize_logger' do
      expect(Logger).to receive(:new).with("#{Rails.root}/log/aca_shop_scheduled_events.log")
      described_class.new(new_date)
    end

    it 'calls shop_daily_events' do
      expect_any_instance_of(described_class).to receive(:shop_daily_events)
      described_class.new(new_date)
    end
  end

  describe '#shop_daily_events' do
    before do
      allow(scheduled_event).to receive(:process_events_for)
    end

    it 'processes open_enrollment_begin and open_enrollment_end events' do
      scheduled_event.shop_daily_events
      expect(scheduled_event).to have_received(:process_events_for).with('open_enrollment_begin').ordered
      expect(scheduled_event).to have_received(:process_events_for).with('open_enrollment_end').ordered
    end
  end

  describe '#auto_transmit_monthly_benefit_sponsors' do
    before do
      allow(scheduled_event).to receive(:aca_shop_market_transmit_scheduled_employers).and_return(true)
      allow(scheduled_event).to receive(:aca_shop_market_employer_transmission_day_of_month).and_return(26)
    end

    context 'when it is the transmission day' do
      it 'calls transmit_scheduled_benefit_sponsors' do
        expect(scheduled_event).to receive(:transmit_scheduled_benefit_sponsors).with(new_date)
        scheduled_event.auto_transmit_monthly_benefit_sponsors
      end
    end

    context 'when it is not the transmission day' do
      let(:new_date) { Date.new(TimeKeeper.date_of_record.year, 3, 25) }

      it 'does not call transmit_scheduled_benefit_sponsors' do
        expect(scheduled_event).not_to receive(:transmit_scheduled_benefit_sponsors)
        scheduled_event.auto_transmit_monthly_benefit_sponsors
      end
    end
  end

  describe '#process_events_for' do
    it 'logs errors when an exception occurs' do
      event = 'test_event'
      error_message = 'Test error'
      logger = instance_double(Logger)
      scheduled_event.instance_variable_set(:@logger, logger)
      allow(logger).to receive(:error)
      allow(scheduled_event).to receive(:notify_logger)

      scheduled_event.send(:process_events_for, event) do
        raise StandardError, error_message
      end

      expect(logger).to have_received(:error).twice
      expect(scheduled_event).to have_received(:notify_logger).exactly(3).times
    end
  end

  describe "initial employer monthly transmission" do
    let(:initial_application_state) { :active }
    let!(:this_year) { TimeKeeper.date_of_record.year }
    let(:april_effective_date) { Date.new(this_year, 4, 1) }
    let!(:employer_A) do
      create(:benefit_sponsors_benefit_sponsorship,
             :with_organization_cca_profile,
             :with_initial_benefit_application,
             initial_application_state: :binder_paid,
             default_effective_period: (april_effective_date..(april_effective_date + 1.year - 1.day)),
             site: site,
             aasm_state: :applicant)
    end
    let!(:employer_B) do
      create(:benefit_sponsors_benefit_sponsorship,
             :with_organization_cca_profile,
             :with_initial_benefit_application,
             initial_application_state: :enrollment_ineligible,
             default_effective_period: (april_effective_date..(april_effective_date + 1.year - 1.day)),
             site: site,
             aasm_state: :applicant)
    end
    let!(:employer_C) do
      create(:benefit_sponsors_benefit_sponsorship,
             :with_organization_cca_profile,
             :with_initial_benefit_application,
             initial_application_state: :enrollment_closed,
             default_effective_period: (april_effective_date..(april_effective_date + 1.year - 1.day)),
             site: site,
             aasm_state: :applicant)
    end

    before :each do
      allow_any_instance_of(described_class).to receive(:aca_shop_market_employer_transmission_day_of_month).and_return(26)
    end

    context "on transmission day (26th of month)" do
      it "should transmit only employer_A" do
        allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(this_year, 3, 26))
        expect(ActiveSupport::Notifications).to receive(:instrument).with("acapi.info.events.employer.benefit_coverage_initial_application_eligible",
                                                                          {employer_id: employer_A.profile.hbx_id, event_name: 'benefit_coverage_initial_application_eligible'})
        described_class.new(Date.new(this_year, 3, 26))
      end

      it "should not transmit employer_B or C" do
        allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(this_year, 3, 26))
        expect(ActiveSupport::Notifications).not_to receive(:instrument).with("acapi.info.events.employer.benefit_coverage_initial_application_eligible",
                                                                              {employer_id: employer_B.profile.hbx_id, event_name: 'benefit_coverage_initial_application_eligible'})
        expect(ActiveSupport::Notifications).not_to receive(:instrument).with("acapi.info.events.employer.benefit_coverage_initial_application_eligible",
                                                                              {employer_id: employer_C.profile.hbx_id, event_name: 'benefit_coverage_initial_application_eligible'})
        described_class.new(Date.new(this_year, 3, 26))
      end
    end
  end
end
