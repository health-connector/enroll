# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::Services::EmployerEvent, :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:event_name) { 'sample_event' }
  let(:event_time) { Time.now }
  let(:employer_profile_id) {benefit_sponsorship.hbx_id}
  let(:employer) { benefit_sponsorship.profile }
  let(:employer_id) { employer.hbx_id }
  let(:plan_year) { employer.benefit_applications.first }
  let(:start_date) { plan_year.effective_period.min.strftime("%Y%m%d") }
  let(:end_date) { plan_year.effective_period.max.strftime("%Y%m%d") }

  let(:resource_body) do
    <<-XML_CODE
     <organization xmlns="http://openhbx.org/api/terms/1.0">
     <id>
     <id>#{employer_id}</id>
     </id>
     <name>#{employer.legal_name}</name>
     <employer_profile>
       <plan_years>
         <plan_year>
           <plan_year_start>#{start_date}</plan_year_start>
           <plan_year_end>#{end_date}</plan_year_end>
         </plan_year>
       </plan_years>
     </employer_profile>
     </organization>
    XML_CODE
  end

  let(:subject) { described_class.new(event_name, resource_body, employer_profile_id) }

  describe 'Initialization' do
    it 'initializes an instance with the correct attributes' do
      expect(subject.event_name).to eq(event_name)
      expect(subject.resource_body).to eq(resource_body)
      expect(subject.employer_profile_id).to eq(employer_profile_id)
    end

    it 'sets the event_time to the current time' do
      expect(subject.event_time).to be_within(1.second).of(Time.now)
    end
  end

  describe '#render_payloads', :dbclean => :after_each do

    let(:profile1) { create(:benefit_sponsors_organizations_issuer_profile, hbx_carrier_id: 20_001) }
    let(:carrier_file_1) { instance_double(BenefitSponsors::EmployerEvents::CarrierFile, rendered_employers: [employer_profile_id], empty?: false) }
    let(:event_renderer) { instance_double(BenefitSponsors::EmployerEvents::Renderer) }
    let(:carrier_1_render_xml) { double }

    context 'when issuer profiles and profiles exist' do
      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([profile1.organization])
        allow(BenefitSponsors::EmployerEvents::CarrierFile).to receive(:new).with(profile1).and_return(carrier_file_1)
        allow(BenefitSponsors::EmployerEvents::Renderer).to receive(:new).with(subject).and_return(event_renderer)
        allow(carrier_file_1).to receive(:render_event_using).with(event_renderer, subject).and_return([carrier_file_1])
      end

      it 'calls the expected methods and interacts with related objects' do
        result = subject.render_payloads

        expect(result).to eq([carrier_file_1])
      end
    end

    context 'when no issuer profiles exist' do
      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([])
        allow(BenefitSponsors::EmployerEvents::Renderer).to receive(:new).with(subject).and_return(event_renderer)
      end

      it 'handles no issuer profiles' do
        result = subject.render_payloads

        expect(result).to eq([])
      end
    end

    context 'when issuer profiles exist but have no profiles' do
      let(:issuer_profile_organization) { create(:benefit_sponsors_organizations_exempt_organization, :with_hbx_profile) }
      # let(:issuer_profile) { create(:benefit_sponsors_organizations_issuer_profile, hbx_carrier_id: 20_001) }

      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([issuer_profile_organization])
        allow(issuer_profile_organization).to receive(:issuer_profile).and_return([])
      end

      it 'handles no profiles within issuer profiles' do
        result = subject.render_payloads

        expect(result).to eq([])
      end
    end
  end
end
