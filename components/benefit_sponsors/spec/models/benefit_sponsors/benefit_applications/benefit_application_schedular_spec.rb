require 'rails_helper'

module BenefitSponsors
  RSpec.describe BenefitApplications::BenefitApplicationSchedular, type: :model, :dbclean => :after_each do
    subject {::BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new}

    describe "#map_binder_payment_due_date_by_start_on" do
      let(:benefit_application_schedular) { BenefitSponsors::BenefitApplications::BenefitApplicationSchedular.new }
      let(:date_hash) do
        {
          "2024-01-01" => '2023,12,26',
          "2024-02-01" => '2024,1,23',
          "2024-03-01" => '2024,2,23',
          "2024-04-01" => '2024,3,25',
          "2024-05-01" => '2024,4,23',
          "2024-06-01" => '2024,5,23',
          "2024-07-01" => '2024,6,24',
          "2024-08-01" => '2024,7,23',
          "2024-09-01" => '2024,8,23',
          "2024-10-01" => '2024,9,23',
          "2024-11-01" => '2024,10,23',
          "2024-12-01" => '2024,11,25',
          "2025-01-01" => '2024,12,23'
        }
      end

      context 'when start on in hash key' do
        it 'should return the corresponding value' do
          date_hash.each do |k, v|
            expect(benefit_application_schedular.map_binder_payment_due_date_by_start_on(Date.parse(k))).to eq(Date.strptime(v, '%Y,%m,%d'))
          end
        end

        it 'should return the correct binder pay date for any year' do
          expect(benefit_application_schedular.map_binder_payment_due_date_by_start_on(Date.parse('2018-11-01'))).to eq(Date.parse('2018-10-23'))
          expect(benefit_application_schedular.map_binder_payment_due_date_by_start_on(Date.parse('2026-05-01'))).to eq(Date.parse('2026-04-23'))
        end
      end
    end

    describe 'start_on_options_with_schedule' do
      let(:dates_hash) { subject.start_on_options_with_schedule(true) }
      let(:first_oe_date) { dates_hash.values.first[:open_enrollment_start_on] }

      it 'should return a instance of Hash' do
        expect(dates_hash).to be_a Hash
      end

      it 'should have sub keys' do
        [:open_enrollment_start_on, :open_enrollment_end_on].each do |dt_key|
          expect(dates_hash.values.first.has_key?(dt_key)).to be_truthy
        end
      end

      if (TimeKeeper.date_of_record).future?
        it "should return today's date for start_on" do
          expect(first_oe_date).to eq TimeKeeper.date_of_record
        end
      end

      context "if the TimeKeeper's day is after monthly_end_on" do
        before :each do
          allow(TimeKeeper).to receive(:date_of_record).and_return(Date.new(2019, 01, 29))
        end

        it 'should return hash with 2 date keys' do
          ba_schedular = subject.start_on_options_with_schedule(true)
          [Date.new(2019, 02, 01), Date.new(2019, 03, 01)].each do |date|
            expect(ba_schedular.keys.include?(date)).to be_truthy
          end
        end

        it 'should return hash with only 1 date key' do
          ba_schedular = subject.start_on_options_with_schedule(false)
          expect(ba_schedular.keys).to eq [Date.new(2019, 03, 01)]
        end
      end
    end

    describe 'calculate_start_on_dates' do
      let(:previous_date) { Date.new(2019, 01, 02) }
      let(:later_date) { Date.new(2019, 01, 28) }
      let(:both_dates) { [Date.new(2019, 02, 01), Date.new(2019, 03, 01)] }

      context 'after open_enrollment_minimum_begin_day_of_month' do
        before :each do
          allow(TimeKeeper).to receive(:date_of_record).and_return(later_date)
        end

        context 'not an admin data table action' do
          it 'should return 1 date' do
            expect(subject.calculate_start_on_dates).to eq [Date.new(2019, 03, 01)]
          end
        end

        context 'not an admin data table action' do
          it 'should return 2 dates' do
            expect(subject.calculate_start_on_dates(true)).to eq both_dates
          end
        end
      end

      context 'before open_enrollment_minimum_begin_day_of_month' do
        before :each do
          allow(TimeKeeper).to receive(:date_of_record).and_return(previous_date)
        end

        context 'not an admin data table action' do
          it 'should return 1 date' do
            expect(subject.calculate_start_on_dates).to eq both_dates
          end
        end

        context 'not an admin data table action' do
          it 'should return 2 dates' do
            expect(subject.calculate_start_on_dates(true)).to eq both_dates
          end
        end
      end
    end

    describe 'open_enrollment_period_by_effective_date' do
      let(:start_on) { Date.new(2019, 02, 01) }
      let(:previous_date) { Date.new(2019, 01, 02) }
      let(:later_date) { Date.new(2019, 01, 28) }
      let(:default_monthly_end_on_date) { Date.new(2019, 01, Settings.aca.shop_market.open_enrollment.monthly_end_on) }
      let(:oe_min_days) { Settings.aca.shop_market.open_enrollment.minimum_length.days }
      let(:oe_start_date) { (start_on - Settings.aca.shop_market.open_enrollment.maximum_length.months.months) }

      context 'after open_enrollment_minimum_begin_day_of_month' do
        before :each do
          allow(TimeKeeper).to receive(:date_of_record).and_return(later_date)
        end

        context 'not an admin data table action' do
          it 'should return 1 date' do
            expect(subject.open_enrollment_period_by_effective_date(start_on, false)).to eq (oe_start_date..default_monthly_end_on_date)
          end
        end

        context 'not an admin data table action' do
          it 'should return 2 dates' do
            expect(subject.open_enrollment_period_by_effective_date(start_on, true)).to eq (oe_start_date..default_monthly_end_on_date)
          end
        end
      end

      context 'before open_enrollment_minimum_begin_day_of_month' do
        before :each do
          allow(TimeKeeper).to receive(:date_of_record).and_return(previous_date)
        end

        context 'not an admin data table action' do
          it 'should return 1 date' do
            expect(subject.open_enrollment_period_by_effective_date(start_on, false)).to eq (oe_start_date..default_monthly_end_on_date)
          end
        end

        context 'not an admin data table action' do
          it 'should return 2 dates' do
            expect(subject.open_enrollment_period_by_effective_date(start_on, true)).to eq (oe_start_date..default_monthly_end_on_date)
          end
        end
      end
    end

    describe 'business_day?' do
      context 'given a business day' do
        it 'should return true' do
          date = Date.new(2024,1,22)
          expect(subject.business_day?(date)).to eq true
        end
      end

      context 'given a holiday' do
        it 'should return false' do
          date = Date.new(2023,6,19) # Juneteenth 2023
          expect(subject.business_day?(date)).to eq false
        end
      end

      context 'given an observed holiday' do
        it 'should return false' do
          date = Date.new(2023,11,10) # Veteran's Day - Saturday 2023, observed on Friday
          expect(subject.business_day?(date)).to eq false
        end
      end
    end
  end
end
