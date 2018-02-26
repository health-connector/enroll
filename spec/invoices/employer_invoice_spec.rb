require "rails_helper"

RSpec.describe EmployerInvoice, dbclean: :after_each do
  let!(:conversion_employer_organization) { FactoryGirl.create(:organization, :conversion_employer_with_expired_and_active_plan_years) }
  let!(:regular_employer_organization) { FactoryGirl.create(:organization, :with_expired_and_active_plan_years) }

  describe ".send_first_invoice_available_notice" do
    before :each do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs = []
    end

     context "Regualr Employers" do
       subject { EmployerInvoice.new(regular_employer_organization, "Rspec_folder") }

       it "should trigger notice" do
         subject.send_first_invoice_available_notice
         queued_job = fetch_job_queue
         expect(queued_job[:args]).to eq [regular_employer_organization.employer_profile.id.to_s, "initial_employer_invoice_available"]
       end
     end

      context "Conversion Employers" do
        subject { EmployerInvoice.new(conversion_employer_organization, "Rspec-folder") }

        it "should trigger notice on employer with plan year is not in renewal state" do
          subject.send_first_invoice_available_notice
          queued_job = fetch_job_queue
         expect(queued_job[:args]).to eq [conversion_employer_organization.employer_profile.id.to_s, "initial_employer_invoice_available"]
        end

        it "should not trigger notice on employer with plan year is in renewal state" do
          conversion_employer_organization.employer_profile.published_plan_year.update_attributes!(:aasm_state => "renewing_draft")
          subject.send_first_invoice_available_notice
          queued_job = fetch_job_queue
          expect(queued_job).to eq nil
        end
      end

    def fetch_job_queue
      ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job_info|
        job_info[:job] == ShopNoticesNotifierJob
      end
    end

  end

  describe ".send_to_print_vendor", dbclean: :after_each do
    let(:active_plan_year){ FactoryGirl.build(:plan_year,start_on:TimeKeeper.date_of_record.next_month.beginning_of_month - 1.year, end_on:TimeKeeper.date_of_record.end_of_month,aasm_state: "active") }
    let(:plan_year){ FactoryGirl.build(:plan_year, aasm_state: "renewing_publish_pending") }
    let(:employer_profile1){ FactoryGirl.build(:employer_profile, plan_years: [active_plan_year,plan_year]) }
    let!(:organization1)  {FactoryGirl.create(:organization,employer_profile:employer_profile1)}
    let!(:employer_invoice) {EmployerInvoice.new(organization1)}

    it "should not send reewning employer notices to print vendor" do
      expect(employer_invoice).not_to receive(:send_to_print_vendor)
      employer_invoice.save_and_notify_with_clean_up
    end

    it "should not send conversion notices to print vendor" do
      employer_profile1.update_attributes!(:profile_source => "conversion")
      plan_year.update_attributes!(:is_conversion => true)
      expect(employer_invoice).not_to receive(:send_to_print_vendor)
      employer_invoice.save_and_notify_with_clean_up
    end

    context "for initial groups", dbclean: :after_each do
      let(:plan_year){ FactoryGirl.build(:plan_year, aasm_state: "enrolling") }
      let(:employer_profile2){ FactoryGirl.build(:employer_profile, aasm_state: "binder_paid", plan_years: [plan_year]) }
      let!(:organization2)  {FactoryGirl.create(:organization, employer_profile:employer_profile2, legal_name: "Initial Employer")}
      let!(:employer_invoice) {EmployerInvoice.new(organization2)}

      it "should not send notice to print vendor" do
        expect(employer_invoice).not_to receive(:send_to_print_vendor)
        employer_invoice.save_and_notify_with_clean_up
      end
    end
  end
end
