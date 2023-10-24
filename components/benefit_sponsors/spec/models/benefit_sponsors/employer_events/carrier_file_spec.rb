# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe BenefitSponsors::EmployerEvents::CarrierFile, "given a carrier", :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:employer_id) { "employer hbx_id" }
  let(:employer) { FactoryGirl.create(:benefit_sponsors_benefit_sponsorship, :with_benefit_market, :with_organization_cca_profile, :with_initial_benefit_application, hbx_id: employer_id)}
  let(:old_plan_year) { employer.benefit_applications.last }
  let(:carrier) {old_plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}

  subject { BenefitSponsors::EmployerEvents::CarrierFile.new(carrier) }

  describe "and asked to render_event_using a renderer, and an employer_event" do
    let(:employer_event) { BenefitSponsors::Services::EmployerEvent.new(:employer_id => employer_id) }
    let(:event_renderer) { instance_double(BenefitSponsors::EmployerEvents::Renderer, :timestamp => Time.now) }
    let(:buffer) { double }

    before :each do
      allow(StringIO).to receive(:new).and_return(buffer)
      allow(event_renderer).to receive(:render_for).with(carrier, buffer)
                                                   .and_return(event_render_result)
      subject.render_event_using(event_renderer, employer_event)
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
