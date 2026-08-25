# frozen_string_literal: true

require 'rails_helper'

describe Aws::S3Storage do

  #allow(:storage_double) {double}
  #allow(Aws::S3Strorage).to receive(:new).and_respond_with(storage_double)
  let(:subject) { Aws::S3Storage.new }
  let(:aws_env) { ENV.fetch('AWS_ENV', "qa") }
  let(:object) { double }
  let(:transfer_manager) { double }
  let(:bucket_name) { "bucket1" }
  let(:env_bucket_name) { "#{Settings.site.s3_prefix}-enroll-#{bucket_name}-#{aws_env}" }
  let(:file_path) { File.dirname(__FILE__) }
  let(:key) { SecureRandom.uuid }
  let(:uri) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{Settings.site.s3_prefix}-enroll-#{bucket_name}-#{aws_env}##{key}" }
  let(:invalid_url) { "urn:openhbx:terms:v1:file_storage:s3:bucket:" }
  let(:file_content) { "test content" }

  describe "save()" do
    before :each do
      allow_any_instance_of(Aws::S3Storage).to receive(:transfer_manager).and_return(transfer_manager)
    end

    context "successful upload with explicit key" do
      it 'uploads with server side encryption and returns the URI of saved file' do
        expect(transfer_manager).to receive(:upload_file).with(file_path, :bucket => env_bucket_name, :key => key, :server_side_encryption => 'AES256').and_return(true)
        expect(subject.save(file_path, bucket_name, key)).to eq(uri)
      end
    end

    context "successful upload without explicit key" do
      it 'return the URI of saved file' do
        allow(transfer_manager).to receive(:upload_file).and_return(true)
        expect(subject.save(file_path, bucket_name)).to include("urn:openhbx:terms:v1:file_storage:s3:bucket:")
      end
    end

    context "failed upload" do
      it 'returns nil' do
        allow(transfer_manager).to receive(:upload_file).and_return(nil)
        expect(subject.save(file_path, bucket_name, key)).to be_nil
      end
    end

    context "when the upload raises an error" do
      before :each do
        allow(transfer_manager).to receive(:upload_file).and_raise(StandardError, "access denied")
      end

      it 'returns nil' do
        expect(subject.save(file_path, bucket_name, key)).to be_nil
      end

      it 'logs the bucket name and the error class' do
        allow(Rails.logger).to receive(:tagged).and_yield
        expect(Rails.logger).to receive(:error).with(/unable to upload file to bucket #{Regexp.escape(env_bucket_name)} due to StandardError/)
        subject.save(file_path, bucket_name, key)
      end
    end
  end

  describe "find()" do
    context "success" do
      it "returns the file contents" do
        allow_any_instance_of(Aws::S3Storage).to receive(:get_object).and_return(object)
        allow_any_instance_of(Aws::S3Storage).to receive(:read_object).with(object).and_return(file_content)
        expect(subject.find(uri)).to eq(file_content)
      end
    end

    context "failure (invalid uri)" do
      it "returns nil" do
        allow_any_instance_of(Aws::S3Storage).to receive(:get_object).with('qa', nil).and_raise(StandardError)
        expect do
          subject.find(invalid_url)
        end.to raise_error(StandardError)
      end
    end
  end
end
