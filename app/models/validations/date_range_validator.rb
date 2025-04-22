# frozen_string_literal: true

module Validations
  class DateRangeValidator < ActiveModel::Validator
    DATA_TYPES = [Date, Time].freeze unless defined?(DATA_TYPES)

    def validate(record)
      record.attributes.each do |key, value|
        next unless DATA_TYPES.include?(value.class)

        if value < TimeKeeper.date_of_record - 110.years
          record.errors.add(key, 'date cannot be more than 110 years ago')
        end
      end
    end
  end
end
