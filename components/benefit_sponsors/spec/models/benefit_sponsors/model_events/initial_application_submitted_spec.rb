require 'rails_helper'

module BenefitSponsors
  RSpec.describe 'ModelEvents::InitialApplicationSubmitted', dbclean: :after_each do

    let(:model_event) { "application_submitted" }
    let(:current_effective_date)  { TimeKeeper.date_of_record }
    let!(:security_question)  { FactoryBot.create_default :security_question }
    let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }

    let(:benefit_market)      { site.benefit_markets.first }
    let!(:benefit_market_catalog) do
      create(
        :benefit_markets_benefit_market_catalog,
        :with_product_packages,
        benefit_market: benefit_market,
        issuer_profile: issuer_profile,
        title: "SHOP Benefits for #{current_effective_date.year}",
        application_period: (start_on.beginning_of_year..start_on.end_of_year)
      )
    end
    let(:organization)        { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:employer_profile)    { organization.employer_profile }
    let!(:benefit_sponsorship) do
      sponsorship = employer_profile.add_benefit_sponsorship
      sponsorship.save
      sponsorship
    end
    let!(:issuer_profile)  { FactoryBot.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
    let!(:model_instance) {
      application = FactoryBot.create(
        :benefit_sponsors_benefit_application,
        :with_benefit_sponsor_catalog,
        benefit_sponsorship: benefit_sponsorship,
        default_effective_period: start_on..start_on.next_year.prev_day,
        open_enrollment_period: open_enrollment_start_on..open_enrollment_start_on + 20.days
      )
      application.benefit_sponsor_catalog.save!
      application
    }
    let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month}
    let(:open_enrollment_start_on) {(TimeKeeper.date_of_record - 1.month).beginning_of_month}

    after :each do
      DatabaseCleaner.clean
    end

    describe "when initial employer's application is approved", dbclean: :after_each do
      context "ModelEvent" do

        it "should trigger model event" do
          model_instance.class.observer_peers.keys.each do |observer|
            expect(observer).to receive(:notifications_send) do |instance, model_event|
              expect(model_event).to be_an_instance_of(::BenefitSponsors::ModelEvents::ModelEvent)
              expect(model_event).to have_attributes(:event_key => :application_submitted, :klass_instance => model_instance, :options => {})
            end
          end
          model_instance.approve_application!
        end
      end

      context "Notice Trigger", dbclean: :after_each do
        subject { BenefitSponsors::Observers::BenefitApplicationObserver.new }

        let(:model_event) { ::BenefitSponsors::ModelEvents::ModelEvent.new(:application_submitted, model_instance, {}) }

        it "should trigger notice event" do
          expect(subject.notifier).to receive(:notify) do |event_name, payload|
            expect(event_name).to eq "acapi.info.events.employer.zero_employees_on_roster_notice"
            expect(payload[:employer_id]).to eq employer_profile.hbx_id.to_s
            expect(payload[:event_object_kind]).to eq 'BenefitSponsors::BenefitApplications::BenefitApplication'
            expect(payload[:event_object_id]).to eq model_instance.id.to_s
          end

          expect(subject.notifier).to receive(:notify) do |event_name, payload|
            expect(event_name).to eq "acapi.info.events.employer.initial_application_submitted"
            expect(payload[:employer_id]).to eq employer_profile.hbx_id.to_s
            expect(payload[:event_object_kind]).to eq 'BenefitSponsors::BenefitApplications::BenefitApplication'
            expect(payload[:event_object_id]).to eq model_instance.id.to_s
          end
          subject.notifications_send(model_instance, model_event)
        end
      end

      context "NoticeBuilder", dbclean: :after_each do

        let(:data_elements) {
          [
            "employer_profile.notice_date",
            "employer_profile.employer_name",
            "employer_profile.benefit_application.current_py_start_date",
            "employer_profile.broker.primary_fullname",
            "employer_profile.broker.organization",
            "employer_profile.broker.phone",
            "employer_profile.broker.email",
            "employer_profile.broker_present?"
          ]
        }
        let(:recipient) { "Notifier::MergeDataModels::EmployerProfile" }
        let(:template)  { Notifier::Template.new(data_elements: data_elements) }
        let(:payload)   { {
            "employer_id" => employer_profile.hbx_id.to_s,
            "event_object_kind" => "BenefitSponsors::BenefitApplications::BenefitApplication",
            "event_object_id" => model_instance.id.to_s
        } }
        let(:merge_model) { subject.construct_notice_object }

        before do
          allow(subject).to receive(:resource).and_return(employer_profile)
          allow(subject).to receive(:payload).and_return(payload)
          model_instance.approve_application!
        end

        context "when notice event received" do

          subject { Notifier::NoticeKind.new(template: template, recipient: recipient) }

          it "should return correct data model" do
            expect(merge_model).to be_a(recipient.constantize)
          end

          it "should return employer legal name" do
            expect(merge_model.employer_name).to eq employer_profile.organization.legal_name
          end

          it "should return plan year start date" do
            expect(merge_model.benefit_application.current_py_start_date).to eq model_instance.start_on.strftime('%m/%d/%Y')
          end

          it "should return broker status" do
            expect(merge_model.broker_present?).to be_falsey
          end
        end
      end
    end
  end
end
