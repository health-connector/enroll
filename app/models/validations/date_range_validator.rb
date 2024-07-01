# frozen_string_literal: true

module Validations
  class DateRangeValidator < ActiveModel::Validator
    DATA_TYPES = [Date, Time].freeze unless defined?(DATA_TYPES)

    def validate(record)
      record.attributes.each_key do |key|
        record.errors[key] << 'date cannot be more than 110 years ago' if DATA_TYPES.include?(record.attributes[key].class) && (record.attributes[key] < TimeKeeper.date_of_record - 110.years)
      end
    end
  end
end