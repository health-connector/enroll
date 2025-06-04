# frozen_string_literal: true

# Utility module to pparse dates
module DateParser
  def self.smart_parse(date_string)
    return nil if date_string.blank?
    return date_string if date_string.is_a?(Date)

    if date_string.is_a?(Time) || date_string.is_a?(DateTime)
      return date_string.strftime("%m/%d/%Y %H:%M")
    end

    case date_string
    when %r{\A\d{2}/\d{2}/\d{4}\z} # MM/DD/YYYY
      Date.strptime(date_string, "%m/%d/%Y")
    when /\A\d{4}-\d{2}-\d{2}\z/ # YYYY-MM-DD
      Date.strptime(date_string, "%Y-%m-%d")
    else
      Date.parse(date_string.to_s)
    end
  rescue ArgumentError
    Rails.logger.error("DateParser: failed to parse input date #{date_string}")
    nil
  end
end

