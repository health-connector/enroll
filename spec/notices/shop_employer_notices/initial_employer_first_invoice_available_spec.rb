# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable do
  let(:employer_profile){ create :employer_profile}
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month - 1.year}
  let(:person){ create :person}
  let!(:plan_year) { FactoryBot.create(:plan_year, employer_profile: employer_profile, start_on: start_on, :aasm_state => 'active') }
  let!(:active_benefit_group) { FactoryBot.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }
  let(:application_event) do
    double("ApplicationEventKind",{
             :name => 'Initial Employer first invoice available in the account',
             :notice_template => 'notices/shop_employer_notices/initial_employer_first_invoice_available_notice',
             :notice_builder => 'ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable',
             :event_name => 'initial_employer_first_invoice_available',
             :mpi_indicator => 'MPI_SHOP20',
             :title => "Your Invoice for Employer Sponsored Coverage is Now Available"
           })
  end
  let(:valid_parmas) do
    {
      :subject => application_event.title,
      :mpi_indicator => application_event.mpi_indicator,
      :event_name => application_event.event_name,
      :template => application_event.notice_template
    }
  end

  describe "New" do
    before do
      allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
    end
    context "valid params" do
      it "should initialze" do
        expect{ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable.new(employer_profile, valid_parmas)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_parmas.delete(key)
          expect{ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable.new(employer_profile, valid_parmas)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    before do
      allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employer_notice = ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable.new(employer_profile, valid_parmas)
    end
    it "should build notice with all necessary info" do
      @employer_notice.build
      expect(@employer_notice.notice.primary_fullname).to eq person.full_name.titleize
      expect(@employer_notice.notice.employer_name).to eq employer_profile.organization.legal_name
      expect(@employer_notice.notice.primary_identifier).to eq employer_profile.hbx_id
    end
  end

  describe "append_data" do
    before do
      allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employer_notice = ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable.new(employer_profile, valid_parmas)
      plan_year = employer_profile.plan_years.where(:aasm_state => "active").first

      @employer_notice.append_data
    end
    it "should return due date" do
      due_date = PlanYear.calculate_open_enrollment_date(plan_year.start_on)[:binder_payment_due_date]
      expect(@employer_notice.notice.plan_year.binder_payment_due_date).to eq due_date
    end
    it "should return start on" do
      expect(@employer_notice.notice.plan_year.start_on).to eq plan_year.start_on
    end
  end

  describe "#generate_pdf_notice" do
    before do
      allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employer_notice = ShopEmployerNotices::InitialEmployerFirstInvoiceAvailable.new(employer_profile, valid_parmas)
    end

    it "should render the notice template" do
      expect(@employer_notice.template).to eq "notices/shop_employer_notices/initial_employer_first_invoice_available_notice"
    end

    it "should generate pdf" do
      @employer_notice.build
      @employer_notice.append_data
      file = @employer_notice.generate_pdf_notice
      expect(File.exist?(file.path)).to be true
    end
  end
end
