# frozen_string_literal: true

module Eligible
  module Entities
    # Entity for Value
    class Value < Dry::Struct
      attribute :title, Types::String.meta(omittable: false)
      attribute :key, Types::String.meta(omittable: false)
    end
  end
end
