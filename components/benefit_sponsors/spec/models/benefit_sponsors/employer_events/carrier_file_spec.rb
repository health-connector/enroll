# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe BenefitSponsors::EmployerEvents::CarrierFile, "given a carrier", :dbclean => :after_each do

  describe "and asked to render_event_using a renderer, and an employer_event" do
    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:event_time) { double }
    let(:employer_profile_id) { "employer hbx_id" }
    let(:employer_profile) { FactoryGirl.create(:benefit_sponsors_benefit_sponsorship, :with_benefit_market, :with_organization_cca_profile, :with_initial_benefit_application, hbx_id: employer_profile_id)}
    let(:employer) { employer_profile.organization }
    let(:employer_id) { employer.hbx_id }
    let(:old_plan_year) { employer_profile.benefit_applications.last }
    let(:old_plan_year_start_date) {old_plan_year.effective_period.min.strftime("%Y%m%d")}
    let(:old_plan_year_end_date) { old_plan_year.effective_period.max.strftime("%Y%m%d")}
    let(:carrier) {old_plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}
    let(:first_time_employer_event_name) { BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME }

    let(:first_time_employer_event) do
      instance_double(BenefitSponsors::Services::EmployerEvent,
                      { event_time: event_time,
                        event_name: first_time_employer_event_name,
                        resource_body: first_time_employer_source_document,
                        employer_profile_id: employer_profile.hbx_id})
    end
    let(:first_time_employer_source_document) do
      <<-XMLCODE
      <organization xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://openhbx.org/api/terms/1.0" xsi:type="EmployerOrganizationType">
        <id>
          <id>#{employer_id}</id>
        </id>
        <name>#{employer.legal_name}</name>
        <fein>#{employer.fein}</fein>
        <office_locations>
          <office_location>
            <id>
              <id>5b46cfafaea91a66a346fd4c</id>
            </id>
            <primary>true</primary>
            <address>
             <type>urn:openhbx:terms:v1:address_type#work</type>
              <address_line_1>245 E OLD STURBRIDGE RD</address_line_1>
              <location_city_name>BRIMFIELD</location_city_name>
              <location_county_name>Hampden</location_county_name>
              <location_state>urn:openhbx:terms:v1:us_state#massachusetts</location_state>
              <location_state_code>MA</location_state_code>
              <postal_code>01010</postal_code>
              <location_country_name/>
              <address_full_text>245 E OLD STURBRIDGE RD  BRIMFIELD, MA 01010</address_full_text>
            </address>
            <phone>
              <type>urn:openhbx:terms:v1:phone_type#work</type>
              <area_code>413</area_code>
              <phone_number>2453100</phone_number>
              <full_phone_number>4132453100</full_phone_number>
              <is_preferred>false</is_preferred>
            </phone>
          </office_location>
        </office_locations>
        <is_active>true</is_active>
        <employer_profile>
          <business_entity_kind>urn:openhbx:terms:v1:employers#s_corporation</business_entity_kind>
          <sic_code>4725</sic_code>
          <plan_years>
            <plan_year>
              <plan_year_start>#{old_plan_year_start_date}</plan_year_start>
              <plan_year_end>#{old_plan_year_end_date}</plan_year_end>
              <fte_count>2</fte_count>
              <pte_count>0</pte_count>
              <open_enrollment_start>20180201</open_enrollment_start>
              <open_enrollment_end>20180320</open_enrollment_end>
              <benefit_groups>
                <benefit_group>
                    <id>
                      <id>5b46d3ddaea91a38fa64aebf</id>
                    </id>
                    <name>Standard</name>
                    <group_size>1</group_size>
                    <participation_rate>0.01</participation_rate>
                    <rating_area>R-MA001</rating_area>
                    <elected_plans>
                      <elected_plan>
                        <id>
                          <id>59763MA0030011-01</id>
                        </id>
                        <name>Direct Gold 1000</name>
                        <active_year>2018</active_year>
                        <is_dental_only>false</is_dental_only>
                        <carrier>
                          <id>
                            <id>20001</id>
                          </id>
                          <name>Tufts Health Direct</name>
                          <is_active>true</is_active>
                        </carrier>
                        <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                        <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                        <ehb_percent>99.5</ehb_percent>
                      </elected_plan>
                    </elected_plans>
                </benefit_group>
              </benefit_groups>
              <created_at>2018-07-12T04:06:53Z</created_at>
              <modified_at>2018-07-12T04:06:53Z</modified_at>
            </plan_year>
          </plan_years>
        </employer_profile>
        <created_at>2018-07-12T03:49:03Z</created_at>
        <modified_at>2019-02-25T22:09:12Z</modified_at>
      </organization>
      XMLCODE
    end
    let(:event_renderer) { instance_double(BenefitSponsors::EmployerEvents::Renderer, timestamp: event_time) }
    let(:buffer) { double }
    subject { BenefitSponsors::EmployerEvents::CarrierFile.new(carrier) }

    before :each do
      allow(StringIO).to receive(:new).and_return(buffer)
      allow(event_renderer).to receive(:render_for).with(carrier, buffer).and_return(event_render_result)
      subject.render_event_using(event_renderer, first_time_employer_event)
    end

    describe "when the employer_event is rendered by the renderer" do
      let(:event_render_result) { true }

      it "is NOT empty" do
        expect(subject.empty?).to be_falsey
      end

      it "has the employer id in rendered_employers" do
        expect(subject.rendered_employers).to include(employer_id)
      end
    end

    describe "when the employer_event is NOT rendered by the renderer" do
      let(:event_render_result) { false }

      it "is empty" do
        expect(subject.empty?).to be_truthy
      end

      it "does not have the employer id in rendered_employers" do
        expect(subject.rendered_employers).not_to include(employer_id)
      end
    end
  end
end
