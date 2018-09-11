require 'rails_helper'

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe BenefitApplications::BenefitApplicationEnrollmentService, type: :model, :dbclean => :after_each do
    let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }

    let(:market_inception) { TimeKeeper.date_of_record.year }
    let(:current_effective_date) { Date.new(market_inception, 8, 1) }

    include_context "setup benefit market with market catalogs and product packages"

    before do
      TimeKeeper.set_date_of_record_unprotected!(Date.today)
    end

    describe '.renew' do
      let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year, 8, 1) }
      let(:aasm_state) { :active }
      let(:business_policy) { instance_double("some_policy", success_results: "validated successfully")}
      include_context "setup initial benefit application"

      before(:all) do
        TimeKeeper.set_date_of_record_unprotected!(Date.new(TimeKeeper.date_of_record.year, 6, 10))
      end

      after(:all) do
        TimeKeeper.set_date_of_record_unprotected!(Date.today)
      end

      subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

      context "when initial employer eligible for renewal" do

        it "should generate renewal application" do
          allow(subject).to receive(:business_policy).and_return(business_policy)
          allow(business_policy).to receive(:is_satisfied?).with(initial_application).and_return(true)
          subject.renew_application
          benefit_sponsorship.reload

          renewal_application = benefit_sponsorship.benefit_applications.detect{|application| application.is_renewing?}
          expect(renewal_application).not_to be_nil

          expect(renewal_application.start_on.to_date).to eq current_effective_date.next_year
          expect(renewal_application.benefit_sponsor_catalog).not_to be_nil
          expect(renewal_application.benefit_packages.count).to eq 1
        end
      end
    end

    describe '.revert_application' do
    end

    describe '.submit_application' do
      let(:market_inception) { TimeKeeper.date_of_record.year - 1 }

      context "when initial employer present with valid application" do

        let(:open_enrollment_begin) { Date.new(TimeKeeper.date_of_record.year, 7, 3) }

        include_context "setup initial benefit application" do
          let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year, 8, 1) }
          let(:open_enrollment_period) { open_enrollment_begin..(effective_period.min - 10.days) }
          let(:aasm_state) { :draft }
        end

        before do
          TimeKeeper.set_date_of_record_unprotected!(Date.new(TimeKeeper.date_of_record.year, 7, 4))
        end

        after(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

        context "open enrollment start date in the past" do

          context "and the benefit_application passes business policy validation" do

            it "should submit application with immediate open enrollment" do
              subject.submit_application
              initial_application.reload
              expect(initial_application.aasm_state).to eq :enrollment_open
              expect(initial_application.open_enrollment_period.begin.to_date).to eq TimeKeeper.date_of_record
            end
          end

          context "and the benefit_application fails business policy validation" do
            let(:business_policy) { instance_double("some_policy", fail_results: { business_rule: "failed validation" })}

            it "application should transition into :draft state" do
              allow(subject).to receive(:business_policy).and_return(business_policy)
              allow(subject).to receive(:business_policy_satisfied_for?).with(:submit_benefit_application).and_return(false)

              subject.submit_application
              initial_application.reload
              expect(initial_application.aasm_state).to eq :draft
            end
          end

        end

        context "open enrollment start date in the future" do
          let(:open_enrollment_begin) { Date.new(TimeKeeper.date_of_record.year, 7, 5) }

          it "should submit application with approved status" do
            subject.submit_application
            initial_application.reload
            expect(initial_application.aasm_state).to eq :approved
          end
        end
      end

      context "when renewing employer present with renewal application" do

      end
    end

    describe '.force_submit_application' do
      include_context "setup initial benefit application"

      context "renewal application in draft state" do

        let(:scheduled_event)  {BenefitSponsors::ScheduledEvents::AcaShopScheduledEvents}

        let!(:renewal_application)  { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application).renew_application[1] }

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(renewal_application) }

        context "today is prior to date for force publish" do
          before(:each) do
            TimeKeeper.set_date_of_record_unprotected!(Date.new(Date.today.year, 8, 15))
          end

          after(:each) do
            TimeKeeper.set_date_of_record_unprotected!(Date.today)
          end

          it "should not change the benefit application" do
            scheduled_event.advance_day(TimeKeeper.date_of_record)
            expect(renewal_application.aasm_state).to eq :draft
          end

        end

        context "today is date for force publish" do

          before(:each) do
            TimeKeeper.set_date_of_record_unprotected!(Date.new(Date.today.year, 8, 11))
          end

          after(:each) do
            TimeKeeper.set_date_of_record_unprotected!(Date.today)
          end

          it "should transition the benefit_application into :enrollment_open" do
            scheduled_event.advance_day(TimeKeeper.date_of_record)
            renewal_application.reload
            expect(renewal_application.aasm_state).to eq :enrollment_open
          end

          context "the active benefit_application has benefits that can be mapped into renewal benefit_application" do
            it "should autorenew all active members"
          end

          context "the active benefit_application has benefits that Cannot be mapped into renewal benefit_application" do
            it "should not autorenew all active members"
          end

        end
      end
    end

    describe '.begin_open_enrollment' do
      context "when initial employer present with valid approved application" do

        let(:open_enrollment_begin) { TimeKeeper.date_of_record - 5.days }

        include_context "setup initial benefit application" do
          let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year, 8, 1) }
          let(:open_enrollment_period) { open_enrollment_begin..(effective_period.min - 10.days) }
          let(:aasm_state) { :approved }
        end

        before(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.new(TimeKeeper.date_of_record.year, 6, 10))
        end

        after(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

        context "open enrollment start date in the past" do

          it "should begin open enrollment" do
            subject.begin_open_enrollment
            initial_application.reload
            expect(initial_application.aasm_state).to eq :enrollment_open
          end
        end

        context "open enrollment start date in the future" do
          let(:open_enrollment_begin) { TimeKeeper.date_of_record + 5.days }

          it "should do nothing" do
            subject.begin_open_enrollment
            initial_application.reload
            expect(initial_application.aasm_state).to eq :approved
          end
        end
      end

      context "when renewing employer present with renewal application" do

      end
    end

    describe '.end_open_enrollment' do
      context "when initial employer successfully completed enrollment period" do

        let(:open_enrollment_close) { TimeKeeper.date_of_record.prev_day }
        let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year, 8, 1) }
        let(:aasm_state) { :enrollment_open }
        let(:open_enrollment_period) { effective_period.min.prev_month..open_enrollment_close }

        include_context "setup initial benefit application" do
          let(:aasm_state) { :enrollment_open }
          let(:benefit_sponsorship_state) { :initial_enrollment_open }
        end

        before(:each) do
          TimeKeeper.set_date_of_record_unprotected!(Date.new(Date.today.year, 7, 24))
        end

        after(:each) do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

        context "open enrollment close date passed" do
          before :each do
            initial_application.benefit_sponsorship.update_attributes(aasm_state: :initial_enrollment_open)
            allow(::BenefitSponsors::SponsoredBenefits::EnrollmentClosePricingDeterminationCalculator).to receive(:call).with(initial_application, Date.new(Date.today.year, 7, 24))
          end

          context "and the benefit_application enrollment passes eligibility policy validation" do

            it "should close open enrollment" do
              subject.end_open_enrollment
              initial_application.reload
              expect(initial_application.aasm_state).to eq :enrollment_closed
            end
          end

          context "and the benefit_application enrollment fails eligibility policy validation" do
            let(:business_policy) { instance_double("some_policy", fail_results: { business_rule: "failed validation" })}

            it "should close open enrollment and transition into :enrollment_ineligible state" do
              allow(subject).to receive(:business_policy).and_return(business_policy)
              allow(subject).to receive(:business_policy_satisfied_for?).with(:end_open_enrollment).and_return(false)

              subject.end_open_enrollment
              initial_application.reload
              expect(initial_application.aasm_state).to eq :enrollment_ineligible
              expect(initial_application.benefit_sponsorship.aasm_state).to eq :initial_enrollment_ineligible
            end
          end


          it "invokes pricing determination calculation" do
            expect(::BenefitSponsors::SponsoredBenefits::EnrollmentClosePricingDeterminationCalculator).to receive(:call).with(initial_application, Date.new(Date.today.year, 7, 24))
            subject.end_open_enrollment
          end
        end

        context "open enrollment close date in the future" do
          let(:open_enrollment_close) { TimeKeeper.date_of_record.next_day }

          it "should do nothing" do
            subject.begin_open_enrollment
            initial_application.reload
            expect(initial_application.aasm_state).to eq :enrollment_open
          end
        end
      end

      context "when renewing employer present with renewal application" do

      end
    end

    describe '.begin_benefit' do

      context "when initial employer completed open enrollment and ready to begin benefit" do

        let(:application_state) { :enrollment_closed }

        include_context "setup initial benefit application" do
          let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year, 8, 1) }
          let(:aasm_state) {  application_state }
        end

        before(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.new(TimeKeeper.date_of_record.year, 7, 24))
        end

        after(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

        context "made binder payment" do
          let(:application_state) { :enrollment_eligible }

          before do
            allow(initial_application).to receive(:transition_benefit_package_members).and_return(true)
          end

          it "should begin benefit" do
            subject.begin_benefit
            initial_application.reload
            expect(initial_application.aasm_state).to eq :active
          end
        end

        context "binder not paid" do

          let(:aasm_state) {  :canceled } # benefit application will be moved to canceled state when binder payment is missed.

          it "should raise an exception" do
            expect{subject.begin_benefit}.to raise_error(StandardError)
          end
        end
      end

      context "when renewing employer present with renewal application" do

      end
    end

    describe '.end_benefit' do
      context "when employer application exists with active application" do

        let(:market_inception) { TimeKeeper.date_of_record.year - 1 }


        include_context "setup initial benefit application" do
          let(:current_effective_date) { Date.new(TimeKeeper.date_of_record.year - 1, 8, 1) }
          let(:aasm_state) { :active }
        end

        before(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.new(TimeKeeper.date_of_record.year, 8, 1))
        end

        after(:all) do
          TimeKeeper.set_date_of_record_unprotected!(Date.today)
        end

        subject { BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(initial_application) }

        context "when end date is in past" do

          before do
            allow(initial_application).to receive(:transition_benefit_package_members).and_return(true)
          end

          it "should close benefit" do
            subject.end_benefit
            initial_application.reload
            expect(initial_application.aasm_state).to eq :expired
          end
        end
      end
    end

    describe '.cancel' do
    end

    describe '.terminate' do
    end

    describe '.reinstate' do
    end

    describe '.application_warnings' do

    context "when an employer publishes a benefit application" do
    let(:current_effective_date)  { TimeKeeper.date_of_record }
    let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:old_benefit_market_catalog) { create(:benefit_markets_benefit_market_catalog, :with_product_packages,
                                            benefit_market: benefit_market,
                                            title: "SHOP Benefits for #{current_effective_date.year - 1.year}",
                                            application_period: (current_effective_date.next_month.beginning_of_month - 1.year ..current_effective_date.end_of_month))
                                          }

    let!(:renewing_benefit_market_catalog) { create(:benefit_markets_benefit_market_catalog, :with_product_packages,
                                            benefit_market: benefit_market,
                                            title: "SHOP Benefits for #{current_effective_date.year}",
                                            application_period: (current_effective_date.next_month.beginning_of_month..current_effective_date.end_of_month + 1.year ))
                                          }

    let(:benefit_market)      { site.benefit_markets.first }
    let!(:product_package_1) { old_benefit_market_catalog.product_packages.first }
    let!(:product_package_2) { renewing_benefit_market_catalog.product_packages.first }

    let!(:rating_area)   { FactoryGirl.create_default :benefit_markets_locations_rating_area }
    let!(:service_area)  { FactoryGirl.create_default :benefit_markets_locations_service_area }
    let!(:security_question)  { FactoryGirl.create_default :security_question }

    let(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    # let!(:employer_attestation)     { BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved") }
    let(:benefit_sponsorship) do
      FactoryGirl.create(
        :benefit_sponsors_benefit_sponsorship,
        :with_rating_area,
        :with_service_areas,
        supplied_rating_area: rating_area,
        service_area_list: [service_area],
        organization: organization,
        profile_id: organization.profiles.first.id,
        benefit_market: site.benefit_markets[0])
    end

    let(:start_on)  { TimeKeeper.date_of_record}
    let(:old_effective_period)  { start_on.next_month.beginning_of_month - 1.year ..start_on.end_of_month }
    let!(:old_benefit_application) {
      application = FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, effective_period: old_effective_period, aasm_state: :active)
      application.benefit_sponsor_catalog.save!
      application
    }

    let(:renewing_effective_period)  { start_on.next_month.beginning_of_month..start_on.end_of_month + 1.year }
    let!(:renewing_benefit_application) {
      application = FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, effective_period: renewing_effective_period, aasm_state: :draft, predecessor_id: old_benefit_application.id)
      application.benefit_sponsor_catalog.save!
      application
    }

    let!(:old_benefit_package) { FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: old_benefit_application, product_package: product_package_1) }
    let!(:renewing_benefit_package) { FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: renewing_benefit_application, product_package: product_package_2, is_active: false, description: "Renewing Benefit package", predecessor_id: old_benefit_package.id ) }

    let(:old_benefit_group_assignment) {FactoryGirl.build(:benefit_sponsors_benefit_group_assignment, benefit_group: old_benefit_package)}
    let(:renewing_benefit_group_assignment) {FactoryGirl.build(:benefit_sponsors_benefit_group_assignment, benefit_group: renewing_benefit_package, is_active: false)}

    let(:employee_role_1) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person_1, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee_1.id) }
    let(:census_employee_1) { FactoryGirl.create(:benefit_sponsors_census_employee,
      employer_profile: benefit_sponsorship.profile,
      is_business_owner: false,
      benefit_sponsorship: benefit_sponsorship,
      benefit_group_assignments: [old_benefit_group_assignment,renewing_benefit_group_assignment]
    )}
    let(:person_1) { FactoryGirl.create(:person) }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person_1)}


    let(:employee_role_2) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person_2, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee_2.id) }
    let(:census_employee_2) { FactoryGirl.create(:benefit_sponsors_census_employee,
      employer_profile: benefit_sponsorship.profile,
      is_business_owner: true,
      benefit_sponsorship: benefit_sponsorship,
      benefit_group_assignments: [old_benefit_group_assignment,renewing_benefit_group_assignment]
    )}
    let(:person_2) { FactoryGirl.create(:person) }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person_2)}
        it "should not give any application warning" do
          subject = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(renewing_benefit_application)
          census_employee_1.save
          census_employee_2.save
          expect(subject.application_warnings).to eq nil
        end
        it "should give application warning" do
          subject = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(renewing_benefit_application)
          census_employee_1.save
          census_employee_1.update_attributes!(is_business_owner: true)
          census_employee_2.save
          expect(subject.application_warnings).not_to eq nil
        end
        it "should give application warning for initial application" do
          subject = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(old_benefit_application)
          census_employee_1.save
          census_employee_1.update_attributes!(is_business_owner: true)
          census_employee_2.save
          expect(subject.application_warnings).not_to eq nil
        end
        it "should not give any application warning for initial application" do
          subject = BenefitSponsors::BenefitApplications::BenefitApplicationEnrollmentService.new(old_benefit_application)
          census_employee_1.save
          census_employee_2.save
          expect(subject.application_warnings).to eq nil
        end
      end
    end
  end
end
