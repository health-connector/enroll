# frozen_string_literal: true

module Eligible
  module Entities
    # Entity for TimeStamp
    class TimeStamp < Dry::Struct
      attribute :created_at, Types::DateTime.optional.meta(omittable: true)
      attribute :modified_at, Types::DateTime.optional.meta(omittable: true)
    end
  end
end
