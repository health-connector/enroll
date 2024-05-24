# frozen_string_literal: true

# Custom validator for validating file uploads. This validator checks the content type, size, and file header of the uploaded file.
class FileValidator < ActiveModel::EachValidator

  # Expected headers for different file types. The header is the first few bytes of the file that uniquely identify the file type.
  FILE_HEADERS = {
    'application/pdf' => "%PDF".b, # Identifies PDF documents
    'image/jpeg' => "\xFF\xD8".b, # Start of Image (SOI) marker for JPEGs
    'image/png' => "\x89PNG".b, # PNG signature
    'image/gif' => "GIF".b, # First three bytes of a GIF image
    'application/vnd.ms-excel' => "\xD0\xCF\x11\xE0".b, # Signature for XLS files
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => "PK\x03\x04".b, # Signature for XLSX files
    'text/csv' => nil # Text files might not have a specific header to check
  }.freeze

  def validate_each(record, attribute, value)
    validate_content_type(record, attribute, value)
    validate_file_size(record, attribute, value)
    validate_file_header(record, attribute, value)
  end

  private

  def validate_content_type(record, attribute, value)
    allowed_types = options[:content_types].call(record) || []

    record.errors.add(attribute, "must be one of: #{allowed_types.join(', ')}") unless allowed_types.include?(value.content_type)
  end

  def validate_file_size(record, attribute, value)
    max_size = options[:size].call(record) || 5.megabytes

    record.errors.add(attribute, "should be less than #{max_size / 1.megabyte} MB") if value.size > max_size
  end

  def validate_file_header(record, attribute, value)
    validate_headers = options.dig(:headers, :validate) || false
    return unless validate_headers

    expected_header = FILE_HEADERS[value.content_type]
    return if expected_header.nil? # Skip validation for file types without unique headers, such as text/csv

    value.open do |file|
      file_header = file.read(expected_header.length)
      record.errors.add(attribute, 'file header does not match the expected file type') unless file_header == expected_header
    end
  end
end
