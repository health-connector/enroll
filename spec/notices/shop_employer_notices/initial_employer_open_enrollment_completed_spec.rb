# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted do
  let(:employer_profile){ create :employer_profile}
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month - 1.year}
  let(:person){ create :person}
  let!(:plan_year) { FactoryBot.create(:plan_year, employer_profile: employer_profile, start_on: start_on, :aasm_state => 'enrolling') }
  let!(:active_benefit_group) { FactoryBot.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }
  let(:application_event) do
    double("ApplicationEventKind",{
             :name => 'Initial Employee Open Enrollment Successfully Completed',
             :notice_template => 'notices/shop_employer_notices/17_initial_employer_open_enrollment_completed',
             :notice_builder => 'ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted',
             :event_name => 'initial_employer_open_enrollment_completed',
             :mpi_indicator => 'MPI_SHOP17',
             :title => "Open Enrollment Completed"
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
        expect{ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted.new(employer_profile, valid_parmas)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_parmas.delete(key)
          expect{ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted.new(employer_profile, valid_parmas)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    before do
      allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employer_notice = ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted.new(employer_profile, valid_parmas)
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
      @employer_notice = ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted.new(employer_profile, valid_parmas)
    end
    it "should append necessary" do
      plan_year = employer_profile.plan_years.where(:aasm_state.in => PlanYear::INITIAL_ELIGIBLE_STATE).first
      due_date = PlanYear.calculate_open_enrollment_date(plan_year.start_on)[:binder_payment_due_date]
      @employer_notice.append_data
      expect(@employer_notice.notice.plan_year.start_on).to eq plan_year.start_on
      expect(@employer_notice.notice.plan_year.binder_payment_due_date).to eq due_date
    end
  end

end