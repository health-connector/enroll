module SponsoredBenefits
  module Validations
    class DateRangeValidator < ActiveModel::Validator
      DATA_TYPES = [Date, Time].freeze unless defined?(DATA_TYPES)

      def validate(record)
        record.attributes.keys.each do |key|
          if DATA_TYPES.include?(record.attributes[key].class) && (record.attributes[key] < TimeKeeper.date_of_record - 110.years)
            record.errors[key] << 'date cannot be more than 110 years ago'
          end
        end
      end
    end
  end
end