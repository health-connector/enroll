# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TimingHelper do
  let(:helper) do
    Class.new { include TimingHelper }.new
  end

  describe '#process_start_time' do
    it 'returns a numeric monotonic timestamp' do
      expect(helper.process_start_time).to be_a(Numeric)
    end

    it 'advances over time' do
      t1 = helper.process_start_time
      t2 = helper.process_start_time
      expect(t2).to be >= t1
    end
  end

  describe '#process_end_time_formatted' do
    it 'returns a zero-padded HH:MM:SS-style string' do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 3723
      result = helper.process_end_time_formatted(start)
      expect(result).to match(/\d{2}hr \d{2}min \d{2}sec/)
    end

    it 'formats sub-minute elapsed time correctly' do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 30
      result = helper.process_end_time_formatted(start)
      expect(result).to eq('00hr 00min 30sec')
    end

    it 'formats elapsed time of exactly 1 hour correctly' do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC) - 3600
      result = helper.process_end_time_formatted(start)
      expect(result).to eq('01hr 00min 00sec')
    end
  end
end
