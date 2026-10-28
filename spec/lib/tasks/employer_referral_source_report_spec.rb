# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'csv'

require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe 'migrations:employer_referral_source_report', :dbclean => :around_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:task_name) { 'migrations:employer_referral_source_report' }
  let(:referral_source) { 'Radio' }
  let(:period_start) { effective_period.min }
  let(:period_end) { effective_period.max }
  let(:output_files) { Dir.glob("#{Rails.root}/public/CCA_*_EMPLOYERREFERRALSOURCEREPORT_*.csv") }

  def run_task(*args)
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke(*args.map { |date| date.strftime('%m/%d/%Y') })
  end

  def quietly
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = $stderr = StringIO.new
    yield
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  def report_rows
    CSV.read(output_files.max).drop(1).to_h { |source, count, _percent| [source, count.to_i] }
  end

  before do
    load File.expand_path("#{Rails.root}/lib/tasks/migrations/employer_referral_source_report.rake", __FILE__)
    Rake::Task.define_task(:environment)
    abc_profile.update_attributes!(referred_by: referral_source)
  end

  after do
    FileUtils.rm_f(output_files)
  end

  context 'with an employer that has an active benefit application' do
    it 'counts the employer under its referral source for a date range overlapping the application' do
      quietly { run_task(period_start, period_end) }

      expect(report_rows[referral_source]).to eq 1
      expect(report_rows['TOTAL']).to eq 1
    end

    it 'counts the employer for a single as-of date inside the application period' do
      quietly { run_task(period_start + 1.month) }

      expect(report_rows[referral_source]).to eq 1
      expect(report_rows['TOTAL']).to eq 1
    end

    it 'lists referral sources with no employers as zero' do
      quietly { run_task(period_start, period_end) }

      expect(report_rows['Television']).to eq 0
    end

    it 'groups a blank referral source separately' do
      abc_profile.update_attributes!(referred_by: nil)
      quietly { run_task(period_start, period_end) }

      expect(report_rows['(Not Specified / Blank)']).to eq 1
    end

    it 'does not count the employer when the dates fall outside the application period' do
      quietly { run_task(period_end + 1.month, period_end + 3.months) }

      expect(report_rows[referral_source]).to eq 0
      expect(report_rows['TOTAL']).to eq 0
    end
  end

  context 'with an employer whose benefit application is not in a coverage state' do
    let(:aasm_state) { :canceled }

    it 'does not count the employer' do
      quietly { run_task(period_start, period_end) }

      expect(report_rows['TOTAL']).to eq 0
    end
  end

  context 'with invalid arguments' do
    it 'aborts when no start date is given' do
      Rake::Task[task_name].reenable
      expect { quietly { Rake::Task[task_name].invoke } }.to raise_error(SystemExit)
    end

    it 'aborts when the end date is before the start date' do
      expect { quietly { run_task(period_end, period_start) } }.to raise_error(SystemExit)
    end

    it 'aborts when a date is not MM/DD/YYYY' do
      Rake::Task[task_name].reenable
      expect { quietly { Rake::Task[task_name].invoke('2026-07-01') } }.to raise_error(SystemExit)
    end
  end
end
