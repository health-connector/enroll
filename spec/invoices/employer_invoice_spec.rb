require "rails_helper"

RSpec.describe EmployerInvoice, dbclean: :after_each do
  let!(:conversion_employer_organization) { FactoryGirl.create(:organization, :conversion_employer_with_expired_and_active_plan_years) }
  let!(:initial_employer_organization) { FactoryGirl.create(:organization, :with_expired_and_active_plan_years) }
  let!(:params_regular) { {recipient: initial_employer_organization.employer_profile, event_object: initial_employer_organization.employer_profile.active_plan_year, notice_event: "initial_employer_invoice_available"} }
  let!(:params_conversion) { {recipient: conversion_employer_organization.employer_profile, event_object: conversion_employer_organization.employer_profile.active_plan_year, notice_event: "initial_employer_invoice_available"} }

  describe ".send_first_invoice_available_notice" do
    before :each do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs = []
    end

     context "For initial Employers" do
       subject { EmployerInvoice.new(initial_employer_organization, "Rspec_folder") }

       it "should trigger notice" do
         expect_any_instance_of(Observers::Observer).to receive(:trigger_notice).with(params_regular).and_return(true)
         subject.send_first_invoice_available_notice
       end
     end

      context "For Conversion Employers" do
        subject { EmployerInvoice.new(conversion_employer_organization, "Rspec-folder") }

        it "should trigger notice for employer with initial plan year only" do
          expect_any_instance_of(Observers::Observer).to receive(:trigger_notice).with(params_conversion).and_return(true)
          subject.send_first_invoice_available_notice
        end

        it "should not trigger notice for employer with renewal plan year" do
          conversion_employer_organization.employer_profile.published_plan_year.update_attributes!(:aasm_state => "renewing_draft")
          expect_any_instance_of(Observers::Observer).not_to receive(:trigger_notice)
          subject.send_first_invoice_available_notice
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
