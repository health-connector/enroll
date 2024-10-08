# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "upload_notice_to_employer_account")

describe UploadNoticeToEmployerAccount, dbclean: :after_each do

  let(:given_task_name) { "upload_notice_to_employer_account" }
  subject { UploadNoticeToEmployerAccount.new(given_task_name, double(:current_scope => nil)) }
  let!(:site) { FactoryBot.build(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:organization) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:bucket_name) { 'notices' }
  let(:file_path) { File.dirname(__FILE__) }
  let(:doc_id) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}{#sample-key" }
  let(:employer_profile) { organization.employer_profile}

  let(:notice_env_support) do
    {
      fein: organization.fein,
      notice_name: 'Special Enrollment Denial Notice',
      file_path: file_path
    }
  end

  def with_modified_env(options, &block)
    ClimateControl.modify(options, &block)
  end

  before(:each) do
    allow(Aws::S3Storage).to receive(:save).with(file_path, bucket_name).and_return(doc_id)
  end

  context "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  context "upload notice" do
    it "should save notice as documents under employer profile" do
      with_modified_env notice_env_support do
        expect(employer_profile.documents.size).to eq 0
        subject.migrate
        employer_profile.reload
        expect(employer_profile.documents.size).to eq 1
      end
    end
  end

  context "create_secure_inbox_message" do
    it "should send secure inbox message to employer account" do
      with_modified_env notice_env_support do
        expect(employer_profile.inbox.messages.size).to eq 0
        subject.migrate
        employer_profile.reload
        expect(employer_profile.inbox.messages.size).to eq 1
      end
    end
  end
end
