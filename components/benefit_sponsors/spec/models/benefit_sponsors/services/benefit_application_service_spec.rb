require 'rails_helper'
require File.join(File.dirname(__FILE__), "..", "..", "..", "support/benefit_sponsors_site_spec_helpers")
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require File.join(File.dirname(__FILE__), "..", "..", "..", "support/benefit_sponsors_product_spec_helpers")
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe ::BenefitSponsors::Services::BenefitApplicationService, type: :model, :dbclean => :after_each do
    subject { ::BenefitSponsors::Services::BenefitApplicationService.new }

    def init_form_for_create
      ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
    end

    def fetch_bs_for_service(ba_form)
      subject.find_benefit_sponsorship(ba_form)
    end

    let(:current_year) { TimeKeeper.date_of_record.year }

    describe "constructor" do
      let(:benefit_sponser_ship) do
        double(
          "BenefitSponsorship",
          {
            :benefit_market => "BenefitMarket",
            :profile_id => "rspec-id",
            :organization => "Organization"
          }
        )
      end
      let(:benefit_factory) { double("BenefitApplicationFactory", benefit_sponser_ship: benefit_sponser_ship) }

      it "should initialize service factory" do
        service_obj = Services::BenefitApplicationService.new(benefit_factory)
        expect(service_obj.benefit_application_factory).to eq benefit_factory
      end
    end

    describe ".store service" do
      include_context "setup benefit market with market catalogs and product packages"

      let(:current_effective_date) { effective_period_start_on }
      let(:effective_period_start_on) { TimeKeeper.date_of_record.end_of_month + 1.day + 1.month }
      let(:effective_period_end_on)   { effective_period_start_on + 1.year - 1.day }
      let(:effective_period)          { effective_period_start_on..effective_period_end_on }

      let(:open_enrollment_period_start_on) { effective_period_start_on.prev_month }
      let(:open_enrollment_period_end_on)   { open_enrollment_period_start_on + 9.days }
      let(:open_enrollment_period)          { open_enrollment_period_start_on..open_enrollment_period_end_on }

      let(:params) do
        {
          open_enrollment_period: open_enrollment_period,
          benefit_application_items: [
            { sequence_id: 0, state: :draft, effective_period: effective_period}
          ]
        }
      end

      let(:benefit_application_form) { FactoryGirl.build(:benefit_sponsors_forms_benefit_application) }
      let!(:invalid_application_form) { BenefitSponsors::Forms::BenefitApplicationForm.new}
      let!(:invalid_benefit_application) { BenefitSponsors::BenefitApplications::BenefitApplication.new }

      let!(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:benefit_sponsorship) do
        FactoryGirl.create(
          :benefit_sponsors_benefit_sponsorship,
          :with_rating_area,
          :with_service_areas,
          supplied_rating_area: rating_area,
          service_area_list: [service_area],
          organization: organization,
          profile_id: organization.profiles.first.id,
          benefit_market: site.benefit_markets[0],
          employer_attestation: employer_attestation
        )
      end

      let(:benefit_application)       { benefit_sponsorship.benefit_applications.new(params) }
      let!(:employer_attestation)     { BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved") }
      let!(:benefit_application_factory) { BenefitSponsors::BenefitApplications::BenefitApplicationFactory }

      before do
        TimeKeeper.set_date_of_record_unprotected!(Date.today)
      end

      context "has received valid attributes" do
        it "should save updated benefit application" do
          service_obj = Services::BenefitApplicationService.new(benefit_application_factory)
          expect(service_obj.store(benefit_application_form, benefit_application)).to eq [true, benefit_application]
        end
      end

      context ".save" do
        it "benefit application form has benefit sponsorship with terminated state should revert to applicant state on save" do
          service_obj = Services::BenefitApplicationService.new(benefit_application_factory)
          benefit_sponsorship.update_attributes(aasm_state: :terminated)
          benefit_application_form['benefit_sponsorship_id'] = benefit_sponsorship.id
          service_obj.save(benefit_application_form)
          benefit_sponsorship.reload
          expect(benefit_sponsorship.aasm_state).to eq :applicant
        end
      end

      context "has received invalid attributes" do
        it "should map the errors to benefit application" do
          allow(benefit_application_factory).to receive(:validate).with(invalid_benefit_application).and_return false
          expect(invalid_application_form.valid?).to be_falsy
          expect(invalid_benefit_application.valid?).to be_falsy
          # TODO: add expectations to match the errors instead of counts
          # expect(invalid_application_form.errors.count).to eq 4
          service_obj = Services::BenefitApplicationService.new(benefit_application_factory)
          expect(service_obj.store(invalid_application_form, invalid_benefit_application)).to eq [false, nil]
          # expect(invalid_application_form.errors.count).to eq 8
        end
      end
    end

    describe ".load_form_metadata" do
      let(:benefit_application_form) { BenefitSponsors::Forms::BenefitApplicationForm.new }
      let(:subject) { BenefitSponsors::Services::BenefitApplicationService.new }
      it "should assign attributes of benefit application to form" do
        subject.load_form_metadata(benefit_application_form)
        expect(benefit_application_form.start_on_options).not_to be nil
      end
    end

    describe ".filter_start_on_options" do

      let(:start_on_options) do
        date = TimeKeeper.date_of_record.beginning_of_month.next_month
        publish_due_date_of_month = Settings.aca.shop_market.initial_application.publish_due_day_of_month
        day_of_month = TimeKeeper.date_of_record.day
        if day_of_month > Settings.aca.shop_market.initial_application.earliest_start_prior_to_effective_on.day_of_month
          day_of_month > publish_due_date_of_month ? [date.next_month] : [date, date.next_month]
        else
          day_of_month >= Settings.aca.shop_market.open_enrollment.monthly_end_on ? [date.next_month] : [date, date.next_month]
        end
      end

      [:termination_pending, :terminated].each do |aasm_state|
        context "when overlapping #{aasm_state} benefit application is present" do
          include_context "setup benefit market with market catalogs and product packages"

          let(:effective_period_start_on) { TimeKeeper.date_of_record.beginning_of_month - 3.months }
          let(:current_effective_date) { effective_period_start_on }
          let(:benefit_market) { site.benefit_markets.first }
          let(:effective_period) { (effective_period_start_on..effective_period_end_on) }
          let(:current_benefit_market_catalog) do
            create(
              :benefit_markets_benefit_market_catalog,
              :with_product_packages,
              benefit_market: benefit_market,
              issuer_profile: issuer_profile,
              title: "SHOP Benefits for #{current_effective_date.year}",
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
            )
          end

          let(:service_areas) do
            ::BenefitMarkets::Locations::ServiceArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).all.to_a
          end

          let(:rating_area) do
            ::BenefitMarkets::Locations::RatingArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).first
          end

          include_context "setup initial benefit application"

          let(:terminated_date) { (effective_period_start_on + 5.months).end_of_month }
          let(:aasm_state) { aasm_state }
          let(:benefit_application_form) { BenefitSponsors::Forms::BenefitApplicationForm.new(benefit_sponsorship_id: benefit_sponsorship.id) }
          let(:subject) { BenefitSponsors::Services::BenefitApplicationService.new }
          let!(:application) do
            initial_application.benefit_application_items.create(
              effective_period: effective_period_start_on..terminated_date,
              sequence_id: 1,
              state: initial_application.aasm_state
            )
            initial_application
          end

          it "should display options" do
            subject.load_form_metadata(benefit_application_form)
            expect(benefit_application_form.start_on_options.keys[0]).to eq start_on_options[0]
          end
        end
      end

      [:draft, :enrollment_ineligible].each do |aasm_state|
        context "when overlapping #{aasm_state} benefit application is present" do
          include_context "setup benefit market with market catalogs and product packages"

          let(:effective_period_start_on) { TimeKeeper.date_of_record.beginning_of_month + 2.months }
          let(:current_effective_date) { effective_period_start_on }
          let(:benefit_market) { site.benefit_markets.first }
          let(:effective_period) { (effective_period_start_on..effective_period_end_on) }

          let(:current_benefit_market_catalog) do
            create(
              :benefit_markets_benefit_market_catalog,
              :with_product_packages,
              benefit_market: benefit_market,
              issuer_profile: issuer_profile,
              title: "SHOP Benefits for #{current_effective_date.year}",
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year)
            )
          end

          let(:service_areas) do
            ::BenefitMarkets::Locations::ServiceArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).all.to_a
          end

          let(:rating_area) do
            ::BenefitMarkets::Locations::RatingArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).first
          end

          include_context "setup initial benefit application"
          let(:aasm_state) { aasm_state }
          let(:benefit_application_form) { BenefitSponsors::Forms::BenefitApplicationForm.new(benefit_sponsorship_id: benefit_sponsorship.id) }
          let(:subject) { BenefitSponsors::Services::BenefitApplicationService.new }

          it "should display options" do
            subject.load_form_metadata(benefit_application_form)
            expect(benefit_application_form.start_on_options.keys).to eq start_on_options
          end
        end
      end
    end

    describe ".load_form_params_from_resource" do
      let!(:site)  { FactoryGirl.create(:benefit_sponsors_site, :with_owner_exempt_organization, :with_benefit_market, :with_benefit_market_catalog_and_product_packages, :cca) }
      let!(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let!(:rating_area)   { FactoryGirl.create_default :benefit_markets_locations_rating_area }
      let!(:service_area)  { FactoryGirl.create_default :benefit_markets_locations_service_area }
      let!(:employer_attestation)     { BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved") }
      let!(:benefit_market) { site.benefit_markets.first }

      let(:benefit_sponsorship) do
        FactoryGirl.create(
          :benefit_sponsors_benefit_sponsorship,
          :with_rating_area,
          :with_service_areas,
          supplied_rating_area: rating_area,
          service_area_list: [service_area],
          organization: organization,
          profile_id: organization.profiles.first.id,
          benefit_market: benefit_market,
          employer_attestation: employer_attestation)
      end

      let(:benefit_application) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship) }
      let(:benefit_application_form) { FactoryGirl.build(:benefit_sponsors_forms_benefit_application, id: benefit_application.id ) }
      let(:subject) { BenefitSponsors::Services::BenefitApplicationService.new }

      it "should assign the form attributes from benefit application" do
         form = subject.load_form_params_from_resource(benefit_application_form)
         expect(form[:start_on]).to eq benefit_application.start_on.to_date.to_s
         expect(form[:end_on]).to eq benefit_application.end_on.to_date.to_s
         expect(form[:open_enrollment_start_on]).to eq benefit_application.open_enrollment_start_on.to_date.to_s
         expect(form[:open_enrollment_end_on]).to eq benefit_application.open_enrollment_end_on.to_date.to_s
         expect(form[:pte_count]).to eq benefit_application.pte_count
         expect(form[:msp_count]).to eq benefit_application.msp_count
      end
    end

    describe '.can_create_draft_ba?' do
      let!(:rating_area)                  { FactoryGirl.create_default :benefit_markets_locations_rating_area }
      let!(:service_area)                 { FactoryGirl.create_default :benefit_markets_locations_service_area }
      let(:site)                          { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:organization)                  { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:employer_profile)              { organization.employer_profile }
      let(:benefit_sponsorship)           { bs = employer_profile.add_benefit_sponsorship
                                            bs.save!
                                            bs }

      let(:start_on)                      { TimeKeeper.date_of_record.beginning_of_month + 2.months }
      let(:end_on)                        { start_on.next_year.prev_day }
      let(:open_enrollment_start_on)      { Date.new(start_on.year, start_on.prev_month.month, 1) }
      let(:open_enrollment_end_on)        { Date.new(start_on.year, start_on.prev_month.month, 20) }

      let!(:current_benefit_market_catalog) do
        create(
          :benefit_markets_benefit_market_catalog,
          :with_product_packages,
          benefit_market: site.benefit_markets.first,
          issuer_profile: issuer_profile,
          title: "SHOP Benefits for #{start_on.year}",
          application_period: (TimeKeeper.date_of_record.beginning_of_year..TimeKeeper.date_of_record.end_of_year)
        )
      end

      let!(:issuer_profile)  { FactoryGirl.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}

      let(:create_ba_params) do
        {
          "start_on" => start_on,
          "end_on" => end_on,
          "fte_count" => "11",
          "open_enrollment_start_on" => Date.new(start_on.year, start_on.prev_month.month, 1),
          "open_enrollment_end_on" => Date.new(start_on.year, start_on.prev_month.month, 20),
          "benefit_sponsorship_id" => benefit_sponsorship.id.to_s
        }
      end

      before do
        @form = init_form_for_create
      end

      context 'for imported' do
        let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :draft) }

        context 'without dt active state' do
          it 'should return true as no bas has dt active state' do
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_truthy
          end
        end
      end

      [:draft, :active, :pending, :enrollment_open, :enrollment_eligible, :enrollment_ineligible, :enrollment_closed, :termination_pending].each do |active_state|
        context 'with dt active state' do
          let(:term_start_on) { TimeKeeper.date_of_record.beginning_of_month }
          let(:term_effective_period) { (term_start_on - 5.months)..term_start_on.end_of_month }

          let!(:ba) do
            application = FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: active_state)
            if active_state == :termination_pending
              application.benefit_application_items.create(
                effective_period: term_effective_period,
                sequence_id: 1,
                state: :termination_pending,
                action_type: :change,
                action_kind: 'nonpayment',
                action_reason: 'Non-payment of premium'
              )
            end
            application
          end

          it "should return true as dt active state exists for one of the #{active_state} bas" do
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_truthy
          end
        end
      end

      #for existing non active states in as per active_states_per_dt_action
      [:terminated, :suspended].each do |non_active_state|
        context 'for benefit applications in non active states' do
          let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: non_active_state) }
          it 'should return false as no bas has dt active state' do
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_falsy
          end
        end
      end

      context 'for termination_pending' do
        let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :termination_pending) }

        context 'with overlapping coverage exists' do
          it 'should return false as dt active state exists for one of the bas' do
            ba.benefit_application_items[0].update_attributes({
              effective_period: Date.new(current_year - 1, 7, 1)..Date.new(current_year, 6, 30),
            })
            create_ba_params['start_on'] = "1/1/#{current_year}"
            @form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_falsy
          end
        end

        context 'with no overlapping coverage' do
          it 'should return false as dt active state exists for one of the bas' do
            create_ba_params['start_on'] = "1/1/#{current_year}"
            @form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
            ba.benefit_application_items.create(
              effective_period: Date.new(current_year - 2, 7, 1)..Date.new(current_year - 1, 6, 30),
              sequence_id: 1,
              state: ba.aasm_state
            )
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_truthy
          end

          it 'should return false as dt active state exists for one of the bas' do
            create_ba_params['start_on'] = "10/1/#{current_year}"
            @form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
            ba.benefit_application_items.create(
              effective_period: Date.new(current_year - 1, 7, 1)..Date.new(current_year, 6, 30),
              sequence_id: 1,
              state: ba.aasm_state
            )
            fetch_bs_for_service(@form)
            expect(subject.can_create_draft_ba?(@form)).to be_truthy
          end
        end
      end

      context 'when only canceled benefit application is present' do
        let(:ba_5_start_on) { TimeKeeper.date_of_record.beginning_of_month }
        let!(:ba_5) do
          FactoryGirl.create(
            :benefit_sponsors_benefit_application,
            :with_benefit_sponsor_catalog,
            benefit_sponsorship: benefit_sponsorship,
            aasm_state: :canceled,
            default_effective_period: ba_5_start_on..ba_5_start_on.next_year.prev_day
          )
        end
        it 'should return true' do
          create_ba_params['start_on'] = ba_5_start_on.next_month.to_s
          @form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
          fetch_bs_for_service(@form)
          expect(subject.can_create_draft_ba?(@form)).to be_truthy
        end
      end

      context 'when no benefit applications are present' do
        it 'should return true' do
          create_ba_params['start_on'] = TimeKeeper.date_of_record.beginning_of_month.to_s
          @form = ::BenefitSponsors::Forms::BenefitApplicationForm.for_create(create_ba_params)
          fetch_bs_for_service(@form)
          expect(subject.can_create_draft_ba?(@form)).to be_truthy
        end
      end
    end

    describe '.create_or_cancel_draft_ba' do
      let!(:rating_area)                  { FactoryGirl.create_default :benefit_markets_locations_rating_area, active_year: effective_period.min.year }
      let!(:service_area)                 { FactoryGirl.create_default :benefit_markets_locations_service_area, active_year: effective_period.min.year }
      let(:site)                          { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:benefit_market)                { site.benefit_markets.first }
      let(:organization)                  { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:employer_profile)              { organization.employer_profile }
      let!(:benefit_sponsorship) do
        bs = employer_profile.add_benefit_sponsorship
        bs.save!
        bs
      end
      let(:start_on)                      { TimeKeeper.date_of_record.beginning_of_month }
      let(:effective_period)              { start_on..start_on.next_year.prev_day }

      let(:new_ba_start_on)               { TimeKeeper.date_of_record.beginning_of_month }
      let(:create_ba_params) do
        {
          "start_on" => new_ba_start_on.to_s,
          "end_on" => new_ba_start_on.next_year.prev_day.to_s,
          "fte_count" => "11",
          "open_enrollment_start_on" => Date.new(new_ba_start_on.year, new_ba_start_on.prev_month.month, 1),
          "open_enrollment_end_on" => Date.new(new_ba_start_on.year, new_ba_start_on.prev_month.month, 20),
          "benefit_sponsorship_id" => benefit_sponsorship.id.to_s
        }
      end
      let!(:issuer_profile)  { FactoryGirl.create :benefit_sponsors_organizations_issuer_profile, assigned_site: site}
      let!(:previous_benefit_market_catalog) do
        create(
          :benefit_markets_benefit_market_catalog,
          :with_product_packages,
          benefit_market: benefit_market,
          issuer_profile: issuer_profile,
          title: "SHOP Benefits for #{new_ba_start_on.prev_year.year}",
          application_period: (new_ba_start_on.prev_year.beginning_of_year...new_ba_start_on.prev_year.end_of_year)
        )
      end
      let!(:current_benefit_market_catalog) do
        create(
          :benefit_markets_benefit_market_catalog,
          :with_product_packages,
          benefit_market: benefit_market,
          issuer_profile: issuer_profile,
          title: "SHOP Benefits for #{new_ba_start_on.year}",
          application_period: (new_ba_start_on.beginning_of_year..new_ba_start_on.end_of_year)
        )
      end

      context 'for admin_datatable_action' do
        before :each do
          create_ba_params.merge!({ pte_count: '0', msp_count: '0', admin_datatable_action: true })
          @form = init_form_for_create
        end

        [:pending, :enrollment_open, :enrollment_ineligible].each do |active_state|

          context "with dt in #{active_state} states" do
            let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :draft) }

            let!(:ba2)  { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: active_state) }

            it 'should return true and instance as ba succesfully created' do
              fetch_bs_for_service(@form)
              @model_attrs = subject.form_params_to_attributes(@form)
              result = subject.create_or_cancel_draft_ba(@form, @model_attrs)
              benefit_sponsorship.reload
              expect(result).to eq [true, benefit_sponsorship.benefit_applications.last]
            end

            it 'the existing benefit application should be turned into cancelled state' do
              fetch_bs_for_service(@form)
              @model_attrs = subject.form_params_to_attributes(@form)
              subject.create_or_cancel_draft_ba(@form, @model_attrs)
              benefit_sponsorship.reload
              expect(benefit_sponsorship.benefit_applications.first).to have_attributes(:aasm_state => :canceled)
            end
          end
        end

        context 'with dt active state' do
          let!(:ba2)  { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, default_effective_period: effective_period, benefit_sponsorship: benefit_sponsorship, aasm_state: :active) }

          it 'should return true and instance as ba succesfully created' do
            fetch_bs_for_service(@form)
            @model_attrs = subject.form_params_to_attributes(@form)
            result = subject.create_or_cancel_draft_ba(@form, @model_attrs)
            benefit_sponsorship.reload
            expect(result).to eq [true, benefit_sponsorship.benefit_applications.last]
          end

          it 'the existing overlapping active application should be moved to retroactive_canceled state' do
            fetch_bs_for_service(@form)
            @model_attrs = subject.form_params_to_attributes(@form)
            subject.create_or_cancel_draft_ba(@form, @model_attrs)
            benefit_sponsorship.reload
            expect(benefit_sponsorship.benefit_applications.pluck(:aasm_state).include?(:retroactive_canceled)).to be_truthy
          end

          context 'when active application does not over lap' do

            before do
              start_on = TimeKeeper.date_of_record.beginning_of_month.prev_year

              ba2.benefit_application_items.create(
                effective_period: start_on..start_on.next_year.prev_day,
                sequence_id: 1,
                state: ba2.aasm_state
              )
            end

            it 'should not terminate' do
              fetch_bs_for_service(@form)
              @model_attrs = subject.form_params_to_attributes(@form)
              subject.create_or_cancel_draft_ba(@form, @model_attrs)
              benefit_sponsorship.reload
              expect(benefit_sponsorship.benefit_applications.active.present?).to be_truthy
            end
          end
        end
      end

      context 'not for admin_datatable_action' do
        let(:end_on) { start_on.next_year.prev_day }
        let(:create_ba_params) do
          {
            "start_on" => start_on,
            "end_on" => end_on,
            "fte_count" => "11",
            "pte_count" => '',
            "open_enrollment_start_on" => Date.new(start_on.year, start_on.prev_month.month, 1),
            "open_enrollment_end_on" => Date.new(start_on.year, start_on.prev_month.month, 20),
            "benefit_sponsorship_id" => benefit_sponsorship.id.to_s
          }
        end

        before :each do
          @form = init_form_for_create
          fetch_bs_for_service(@form)
          @model_attrs = subject.form_params_to_attributes(@form)
        end

        it 'should return true and instance as ba succesfully created and preserve default values' do
          result = subject.create_or_cancel_draft_ba(@form, @model_attrs)
          benefit_sponsorship.reload
          new_ba = benefit_sponsorship.benefit_applications.first
          expect(result).to eq [true, new_ba]
          expect(new_ba.pte_count).to eq 0
        end
      end

      [:termination_pending, :terminated, :enrollment_eligible, :enrollment_closed].each do |aasm_state|
        context "has overlapping #{aasm_state} application" do

          let(:effective_period_start_on) { TimeKeeper.date_of_record.beginning_of_month }
          let(:current_effective_date) { effective_period_start_on }
          let(:benefit_market) { site.benefit_markets.first }
          let(:effective_period) { (effective_period_start_on..effective_period_end_on) }

          let(:service_areas) do
            ::BenefitMarkets::Locations::ServiceArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).all.to_a
          end

          let(:rating_area) do
            ::BenefitMarkets::Locations::RatingArea.where(
              :active_year => current_benefit_market_catalog.application_period.min.year
            ).first
          end

          include_context "setup initial benefit application"

          let(:terminated_date) { (effective_period_start_on + 2.months).end_of_month }
          let(:aasm_state) { aasm_state }
          let(:benefit_application_form) { BenefitSponsors::Forms::BenefitApplicationForm.new(benefit_sponsorship_id: benefit_sponsorship.id) }
          let(:subject) { BenefitSponsors::Services::BenefitApplicationService.new }
          let!(:application) do
            unless aasm_state == :enrollment_ineligible
              initial_application.benefit_application_items.create(
                effective_period: effective_period_start_on..terminated_date,
                sequence_id: 1,
                state: initial_application.aasm_state
              )
            end
            initial_application
          end

          let(:create_ba_params) do
            {
              "start_on" => effective_period.min.to_s, "end_on" => effective_period.max.to_s, "fte_count" => "11",
              "open_enrollment_start_on" => "01/15/2019", "open_enrollment_end_on" => "01/20/2019",
              "benefit_sponsorship_id" => benefit_sponsorship.id.to_s
            }
          end

          before do
            @form = init_form_for_create
            subject.load_form_metadata(benefit_application_form)
            @model_attrs = subject.form_params_to_attributes(@form)
            @result = subject.create_or_cancel_draft_ba(@form, @model_attrs)
          end

          it "should raise error" do
            expect(@form.errors.full_messages).to eq ['Existing plan year with overlapping coverage exists']
            expect(@result).to eq [false, nil]
          end
        end
      end
    end

    describe '.has_an_active_ba?' do
      let!(:rating_area)                  { FactoryGirl.create_default :benefit_markets_locations_rating_area }
      let!(:service_area)                 { FactoryGirl.create_default :benefit_markets_locations_service_area }
      let(:site)                          { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
      let(:organization)                  { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
      let(:employer_profile)              { organization.employer_profile }
      let(:benefit_sponsorship) do
        bs = employer_profile.add_benefit_sponsorship
        bs.save!
        bs
      end

      let(:create_ba_params) do
        {
          "start_on" => "02/01/#{current_year}",
          "end_on" => "01/31/#{current_year + 1}",
          "fte_count" => "11",
          "open_enrollment_start_on" => "01/15/#{current_year}",
          "open_enrollment_end_on" => "01/20/#{current_year}",
          "benefit_sponsorship_id" => benefit_sponsorship.id.to_s
        }
      end

      [:active, :pending, :enrollment_open, :enrollment_eligible, :enrollment_closed, :enrollment_ineligible].each do |active_state|
        context 'for benefit applications in active states' do
          let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, benefit_sponsorship: benefit_sponsorship, aasm_state: active_state) }

          it 'should return true as no bas has dt active state' do
            fetch_bs_for_service(init_form_for_create)
            expect(subject.has_an_active_ba?).to be_truthy
          end
        end
      end

      [:terminated, :canceled, :suspended].each do |non_active_state|
        context 'for benefit applications in non active states' do
          let!(:ba) { FactoryGirl.create(:benefit_sponsors_benefit_application, benefit_sponsorship: benefit_sponsorship, aasm_state: non_active_state) }
          it 'should return true as no bas has dt active state' do
            fetch_bs_for_service(init_form_for_create)
            expect(subject.has_an_active_ba?).to be_falsy
          end
        end
      end
    end
  end
end
