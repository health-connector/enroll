# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe BenefitSponsors::Services::EmployerEvent, :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:event_name) { 'sample_event' }
  let(:employer_id) { '12345' }
  let(:event_time) { Time.now }
  let(:benefit_sponsorship) { create(:benefit_sponsors_benefit_sponsorship, :with_benefit_market, :with_organization_cca_profile, :with_initial_benefit_application, hbx_id: employer_id) }
  let(:employer) {employer.profile}
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
  let(:subject) {described_class.new(event_name, resource_body, employer_id)}

  xdescribe 'Initialization' do
    it 'initializes an instance with the correct attributes' do
      employer_event = described_class.new(event_name, resource_body, employer_id)
      expect(employer_event.event_name).to eq(event_name)
      expect(employer_event.resource_body).to eq(resource_body)
      expect(employer_event.employer_id).to eq(employer_id)
    end
  end

  xdescribe '.render_payloads', :dbclean => :after_each do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:site) { BenefitSponsors::SiteSpecHelpers.create_cca_site_with_hbx_profile_and_empty_benefit_market }
    let(:profile1) { create(:benefit_sponsors_organizations_issuer_profile, hbx_carrier_id: 20_001) }
    let(:profile2) { create(:benefit_sponsors_organizations_issuer_profile, hbx_carrier_id: 20_004) }
    let(:issuer_profile_organization) { create(:benefit_sponsors_organizations_exempt_organization, :with_hbx_profile) }
    let(:carrier_file1) { instance_double(BenefitSponsors::EmployerEvents::CarrierFile) }
    let(:carrier_file2) { instance_double(BenefitSponsors::EmployerEvents::CarrierFile) }
    let(:renderer) { instance_double(BenefitSponsors::EmployerEvents::Renderer) }

    context 'when issuer profiles and profiles exist' do
      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([issuer_profile_organization])
        allow(issuer_profile_organization).to receive(:profiles).and_return([profile1, profile2])
        allow(BenefitSponsors::EmployerEvents::CarrierFile).to receive(:new)
        allow(BenefitSponsors::EmployerEvents::Renderer).to receive(:new)
        allow(BenefitSponsors::EmployerEvents::CarrierFile).to receive(:new).with(profile1).and_return(carrier_file1)
        allow(BenefitSponsors::EmployerEvents::CarrierFile).to receive(:new).with(profile2).and_return(carrier_file2)
        allow(BenefitSponsors::EmployerEvents::Renderer).to receive(:new).with(described_class).and_return(renderer)
        allow(carrier_file1).to receive(:render_event_using)
        allow(carrier_file2).to receive(:render_event_using)
      end

      it 'calls the expected methods and interacts with related objects' do
        subject.render_payloads
        expect(BenefitSponsors::EmployerEvents::CarrierFile).to have_received(:new).with(profile1).once
        expect(BenefitSponsors::EmployerEvents::CarrierFile).to have_received(:new).with(profile2).once
        expect(BenefitSponsors::EmployerEvents::Renderer).to have_received(:new).with(subject).once
        expect(carrier_file1).to have_received(:render_event_using).with(renderer, subject).once
        expect(carrier_file2).to have_received(:render_event_using).with(renderer, subject).once
      end
    end

    context 'when no issuer profiles exist' do
      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([])
      end

      it 'handles no issuer profiles gracefully' do
        expect { subject.render_payloads }.not_to raise_error
      end
    end

    context 'when issuer profiles exist but have no profiles' do
      let(:site) { BenefitSponsors::SiteSpecHelpers.create_cca_site_with_hbx_profile_and_empty_benefit_market }
      let(:issuer_profile) { create(:benefit_sponsors_organizations_issuer_profile, assigned_site: site, hbx_carrier_id: 20_001) }

      before do
        allow(BenefitSponsors::Organizations::ExemptOrganization).to receive(:issuer_profiles).and_return([issuer_profile])
      end

      xit 'handles no profiles within issuer profiles gracefully' do
        expect { subject.render_payloads }.not_to raise_error
      end
    end
  end
end
