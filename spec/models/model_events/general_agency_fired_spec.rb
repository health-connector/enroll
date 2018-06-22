require 'rails_helper'

describe 'ModelEvents::GeneralAgencyFired', dbclean: :around_each  do
  let(:model_event)  { "general_agency_fired" }
  let(:notice_event) { "general_agency_fired" }
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month}
  let!(:model_instance) { create(:general_agency_profile, organization: organization) }
  let!(:employer_profile){ FactoryGirl.create :employer_profile }
  let!(:organization) { FactoryGirl.create(:organization, legal_name: 'EmployerA Inc', dba: 'EmployerA') }
  let!(:employer_staff_role) { FactoryGirl.create(:employer_staff_role, person: person, employer_profile_id: employer_profile.id) }
  let!(:general_agency_account) { FactoryGirl.create :general_agency_account, aasm_state: 'inactive',employer_profile: employer_profile, general_agency_profile_id: model_instance.id, end_on: TimeKeeper.date_of_record}
  let!(:general_agency_staff_role) { FactoryGirl.create(:general_agency_staff_role, general_agency_profile_id: model_instance.id)}
  let!(:person){ create :person }
 
  describe "ModelEvent" do
    context "when general_agency is hired" do
      it "should trigger model event" do
        model_instance.observer_peers.keys.each do |observer|
          expect(observer).to receive(:general_agency_profile_update) do |model_event|
            expect(model_event).to be_an_instance_of(ModelEvents::ModelEvent)
            expect(model_event).to have_attributes(:event_key => :general_agency_fired, :klass_instance => model_instance, :options => {})
          end
        end
        model_instance.trigger_model_event(:general_agency_fired)
      end
    end
  end

  describe "NoticeTrigger" do
    context "when event_key is general_agency_fired" do
      subject { Observers::NoticeObserver.new }
      it "should trigger notice event" do
        expect(subject.notifier).to receive(:notify) do |event_name, payload|
          expect(event_name).to eq "acapi.info.events.general_agency.general_agency_fired"
          expect(payload[:event_object_kind]).to eq 'EmployerProfile'
          expect(payload[:event_object_id]).to eq employer_profile.id.to_s
        end
        subject.deliver(recipient: model_instance, event_object: employer_profile, notice_event: "general_agency_fired")
      end
    end
  end

  describe "NoticeBuilder" do
    let(:data_elements) {
      [
          "general_agency.notice_date",
          "general_agency.employer_name",
          "general_agency.legal_name",
          "general_agency.first_name",
          "general_agency.last_name",
          "general_agency.termination_date",
          "general_agency.employer_poc_firstname",
          "general_agency.employer_poc_lastname",
      ]
    }
    let(:recipient) { "Notifier::MergeDataModels::GeneralAgency" }
    let(:template)  { Notifier::Template.new(data_elements: data_elements) }
    let(:payload)   { {
        "event_object_kind" => "EmployerProfile",
        "event_object_id" => employer_profile.id
    } }
    let(:subject) { Notifier::NoticeKind.new(template: template, recipient: recipient) }
    let(:merge_model) { subject.construct_notice_object }

    before do
      allow(subject).to receive(:resource).and_return(model_instance)
      allow(subject).to receive(:payload).and_return(payload)
    end

    it "should return merge model" do
      expect(merge_model).to be_a(recipient.constantize)
    end

    it "should return notice date" do
      expect(merge_model.notice_date).to eq TimeKeeper.date_of_record.strftime('%m/%d/%Y')
    end

    it "should return employer_name" do
      expect(merge_model.employer_name).to eq employer_profile.legal_name
    end

    it "should return general_agency first_name and last_name" do
      expect(merge_model.first_name).to eq general_agency_staff_role.person.first_name
      expect(merge_model.last_name).to eq general_agency_staff_role.person.last_name
    end

    it "should return general_agency termination_date" do
      expect(merge_model.termination_date).to eq general_agency_account.end_on.strftime('%m/%d/%Y')
    end

    it "should return broker agency name " do
      expect(merge_model.legal_name).to eq general_agency_account.general_agency_profile.legal_name
    end

    it "should return employer poc name" do
      expect(merge_model.employer_poc_firstname).to eq employer_staff_role.person.first_name
      expect(merge_model.employer_poc_lastname).to eq employer_staff_role.person.last_name
    end
  end
end
