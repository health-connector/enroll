# frozen_string_literal: true

module Eligible
  module Contracts
    # Contract for TimeStamp
    class TimeStampContract < Dry::Validation::Contract
      params do
        optional(:created_at).maybe(:date_time)
        optional(:modified_at).maybe(:date_time)
      end
    end
  end
end
