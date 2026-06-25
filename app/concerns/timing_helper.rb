# frozen_string_literal: true

module TimingHelper
  def process_start_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def process_end_time_formatted(start_time)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    format('%<h>02dhr %<m>02dmin %<s>02dsec', h: elapsed / 3600, m: elapsed / 60 % 60, s: elapsed % 60)
  end
end
