# frozen_string_literal: true

require 'rails_helper'

# Assume the existence of a dummy model for testing purposes
class DummyModel
  include ActiveModel::Validations
  include ActiveModel::Model
  attr_accessor :file

  validates :file, file:  {
                            content_types: ->(record) { ['application/pdf'] },
                            size: ->(record) { 10.megabytes },
                            headers: {validate: true}
                          }
end

RSpec.describe FileUploadValidator, type: :validator do
  let(:dummy) { DummyModel.new }
  let(:large_file) { double('file') }

  context 'with a valid PDF file' do
    before do
      file = fixture_file_upload("#{Rails.root}/spec/test_data/files/JavaScript.pdf", 'application/pdf')
      dummy.file = file
    end

    it 'is valid' do
      expect(dummy).to be_valid
    end
  end

  context 'with an invalid file type' do
    before do
      file = fixture_file_upload("#{Rails.root}/spec/test_data/files/sample.docx", 'image/jpeg')
      dummy.file = file
    end

    it 'is invalid' do
      expect(dummy).not_to be_valid
    end

    it 'returns a content type error message' do
      dummy.valid?
      expect(dummy.errors[:file]).to include(match('must be one of: application/pdf'))
    end
  end

end
