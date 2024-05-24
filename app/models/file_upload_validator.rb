# frozen_string_literal: true

# This is not an ActiveRecord model, but rather a virtual model for holding and validating file uploads using the ActiveModel API.
class FileUploadValidator
  include ActiveModel::Model
  include ActiveModel::Validations

  # Common content type groups.
  VERIFICATION_DOC_TYPES = %w[application/pdf image/jpeg image/png image/gif].freeze
  XLS_TYPES = %w[application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet].freeze
  CSV_TYPES = %w[text/csv].freeze
  PDF_TYPE = ['application/pdf'].freeze

  attr_accessor :file_data, :allowed_content_types

  validates :file_data, file: {
    content_types: ->(record) { record.allowed_content_types },
    size: ->(record) { record.file_size_limit_in_mb.megabytes },
    headers: {validate: true}
  }

  def initialize(file_data:, content_types:)
    @file_data = file_data
    @allowed_content_types = content_types
  end

  def file_size_limit_in_mb
    EnrollRegistry[:upload_file_size_limit_in_mb].item.to_i
  end

  def human_readable_file_types
    mime_type_to_readable_name = {
      'application/pdf' => 'PDF',
      'image/jpeg' => 'JPEG',
      'image/png' => 'PNG',
      'image/gif' => 'GIF',
      'text/csv' => 'CSV',
      'application/vnd.ms-excel' => 'XLS',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'XLSX'
      # Additional mappings as needed...
    }.freeze

    @allowed_content_types.map { |type| mime_type_to_readable_name[type] || type.split('/').last.upcase }.join(', ')
  end

  # def validate(file:, content_types:)
  #   file_validator = self.new(
  #     file_data: file,
  #     content_types: content_types
  #   )

  #   return true if file_validator.valid?
  #     flash[:error] = l10n(
  #       "upload_doc_error",
  #       file_types: file_validator.human_readable_file_types,
  #       size_in_mb: EnrollRegistry[:upload_file_size_limit_in_mb].item
  #     )
  #     false # Return false to indicate failure
  # end
end
