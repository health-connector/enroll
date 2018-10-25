require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "upload_notice_to_account")

describe UploadNoticeToAccount, dbclean: :after_each do

  let(:given_task_name) { "upload_notice_to_account" }
  subject { UploadNoticeToAccount.new(given_task_name, double(:current_scope => nil)) }
  let!(:site) { FactoryGirl.build(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile_initial_application, site: site) }
  let(:bucket_name) { 'notices' }
  let(:file_path) { File.dirname(__FILE__) }
  let(:doc_id) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}{#sample-key" }
  let(:employer_profile) { organization.employer_profile}
  let(:benefit_sponsorship) { employer_profile.active_benefit_sponsorship }
  let!(:person){ FactoryGirl.create(:person, :with_family)}
  let!(:family) {person.primary_family}
  let!(:census_employee)  { FactoryGirl.create(:benefit_sponsors_census_employee, benefit_sponsorship: benefit_sponsorship, employer_profile: employer_profile ) }
  let!(:employee_role) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person, employer_profile: employer_profile, census_employee_id: census_employee.id)}

  describe "UploadNoticeToEmployersAccount" do
    before(:each) do
      allow(ENV).to receive(:[]).with('profile').and_return("employer")
      allow(ENV).to receive(:[]).with('fein').and_return(organization.fein)
      allow(ENV).to receive(:[]).with('notice_name').and_return('Special Enrollment Denial Notice')
      allow(ENV).to receive(:[]).with('file_path').and_return(file_path)
      allow(Aws::S3Storage).to receive(:save).with(file_path, bucket_name).and_return(doc_id)
    end

    context "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    context "upload notice" do
      it "should save notice as documents under employer profile" do
        expect(employer_profile.documents.size).to eq 0
        subject.migrate
        employer_profile.reload
        expect(employer_profile.documents.size).to eq 1
      end
    end

    context "create_secure_inbox_message" do
      it "should send secure inbox message to employer account" do
        expect(employer_profile.inbox.messages.size).to eq 0
        subject.migrate
        employer_profile.reload
        expect(employer_profile.inbox.messages.size).to eq 1
      end
    end
  end

  describe "UploadNoticeToEmployeesAccount" do
    before(:each) do
      allow(ENV).to receive(:[]).with('profile').and_return("Employee")
      allow(ENV).to receive(:[]).with('hbx_id').and_return(person.hbx_id)
      allow(ENV).to receive(:[]).with('notice_name').and_return('Special Enrollment Denial Notice')
      allow(ENV).to receive(:[]).with('file_path').and_return(file_path)
      allow(Aws::S3Storage).to receive(:save).with(file_path, bucket_name).and_return(doc_id)
    end

    context "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    context "upload notice" do
      it "should save notice as documents under employer profile" do
        expect(person.documents.size).to eq 0
        subject.migrate
        person.reload
        expect(person.documents.size).to eq 1
      end
    end

    context "create_secure_inbox_message" do
      it "should send secure inbox message to employer account" do
        expect(person.inbox.messages.size).to eq 1
      end
    end
  end
end
