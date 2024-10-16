# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

module BenefitSponsors
  RSpec.describe BenefitPackages::BenefitPackage, type: :model, :dbclean => :after_each do
    before do
      DatabaseCleaner.clean
    end

    let!(:rating_area) { create_default(:benefit_markets_locations_rating_area) }

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup initial benefit application"

    let(:title)                 { "Generous BenefitPackage - 2018"}
    let(:probation_period_kind) { :first_of_month_after_30_days }

    let(:params) do
      {
        title: title,
        probation_period_kind: probation_period_kind
      }
    end

    context "A new model instance" do
      it { is_expected.to be_mongoid_document }
      it { is_expected.to have_field(:title).of_type(String).with_default_value_of("")}
      it { is_expected.to have_field(:description).of_type(String).with_default_value_of("")}
      it { is_expected.to have_field(:probation_period_kind).of_type(Symbol)}
      it { is_expected.to have_field(:is_default).of_type(Mongoid::Boolean).with_default_value_of(false)}
      it { is_expected.to have_field(:is_active).of_type(Mongoid::Boolean).with_default_value_of(true)}
      it { is_expected.to have_field(:predecessor_id).of_type(BSON::ObjectId)}
      it { is_expected.to embed_many(:sponsored_benefits)}
      it { is_expected.to be_embedded_in(:benefit_application)}


      context "with no arguments" do
        subject { described_class.new }

        it "should not be valid" do
          subject.validate
          expect(subject).to_not be_valid
        end
      end

      context "with no title" do
        subject { described_class.new(params.except(:title)) }

        it "should not be valid" do
          subject.validate
          expect(subject).to_not be_valid
        end
      end

      context "with no probation_period_kind" do
        subject { described_class.new(params.except(:probation_period_kind)) }

        it "should not be valid" do
          subject.validate
          expect(subject).to_not be_valid
        end
      end

      context "with all required arguments" do
        subject { described_class.new(params) }


        context "and all arguments are valid" do
          it "should be valid" do
            subject.validate
            expect(subject).to be_valid
          end
        end
      end
    end

    describe '.census_employees_assigned_on' do
      let(:renewed_enrollment) { double("hbx_enrollment")}
      let(:ra) {initial_application.renew}
      let(:ia) {predecessor_application}
      let(:bs) { ra.predecessor.benefit_sponsorship}
      let(:cbp){ra.predecessor.benefit_packages.first}
      let(:rbp){ra.benefit_packages.first}
      let!(:rhsb) do
        sb = rbp.health_sponsored_benefit
        sb.product_package_kind = :single_product
        sb.save
        sb
      end
      let(:ibp){ia.benefit_packages.first}
      let(:roster_size) { 5 }
      let(:enrollment_kinds) { ['health'] }
      let!(:census_employees) { create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: bs, employer_profile: bs.profile, benefit_group: cbp) }
      let!(:person) { create(:person) }
      let!(:family) {create(:family, :with_primary_family_member, person: person)}
      let!(:employee_role) { create(:benefit_sponsors_employee_role, person: person)}
      let!(:census_employee) { census_employees.first }
      let(:hbx_enrollment) do
        build(
          :hbx_enrollment,
          :shop,
          household: family.active_household,
          product: cbp.sponsored_benefits.first.reference_product,
          coverage_kind: :health,
          employee_role_id: census_employee.employee_role.id,
          sponsored_benefit_package_id: cbp.id,
          benefit_group_assignment_id: census_employee.benefit_group_assignments.last.id
        )
      end

      let(:renewal_product_package)    { renewal_benefit_market_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
      let(:product) { renewal_product_package.products[0] }

      let!(:update_product) do
        reference_product = current_benefit_package.sponsored_benefits.first.reference_product
        reference_product.renewal_product = product
        reference_product.save!
      end

      let(:active_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: ibp, census_employee: census_employee)}
      let(:renewal_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: rbp, census_employee: census_employee)}

      let(:renewal_benefit_package) { ra.benefit_packages.last }

      before :each do
        ra.benefit_packages.build(title: "Fake Title", probation_period_kind: ::BenefitMarkets::PROBATION_PERIOD_KINDS.sample).save!
        new_benefit_package = ra.benefit_packages.last
        renewal_benefit_package.benefit_sponsorship.census_employees.each do |census_employee|
          census_employee.add_renew_benefit_group_assignment([new_benefit_package])
          census_employee.benefit_group_assignments.each do |bga|
            allow(bga).to receive(:start_on).and_return(ra.start_on)
          end
        end
      end

      it "should return census employees by the benefit_packages package and assignment date" do
        expect(renewal_benefit_package.census_employees_assigned_on(ra.start_on).last.class).to eq(CensusEmployee)
      end

      it "should return blank if no census employees in non term and pending state" do
        renewal_benefit_package.benefit_sponsorship.census_employees.update_all(aasm_state: 'employment_terminated')
        expect(renewal_benefit_package.census_employees_assigned_on(ra.start_on).length).to eq(0)
      end
    end

    describe ".renew" do
      context "when passed renewal benefit package to current benefit package for renewal" do

        let(:renewal_application)             { initial_application.renew }
        let(:renewal_benefit_sponsor_catalog) { renewal_application.benefit_sponsor_catalog }
        let!(:renewal_benefit_package)        { renewal_application.benefit_packages.build }

        before do
          current_benefit_package.renew(renewal_benefit_package)
        end

        it "should have valid applications" do
          initial_application.validate
          renewal_application.validate
          expect(initial_application).to be_valid
          expect(renewal_application).to be_valid
        end

        it "should renew benefit package" do
          expect(renewal_benefit_package).to be_present
          expect(renewal_benefit_package.title).to eq current_benefit_package.title + "(#{renewal_benefit_package.start_on.year})"
          expect(renewal_benefit_package.description).to eq current_benefit_package.description
          expect(renewal_benefit_package.probation_period_kind).to eq current_benefit_package.probation_period_kind
          expect(renewal_benefit_package.is_default).to eq current_benefit_package.is_default
        end

        it "should renew sponsored benefits" do
          expect(renewal_benefit_package.sponsored_benefits.size).to eq current_benefit_package.sponsored_benefits.size
        end

        it "should reference to renewal product package" do
          renewal_benefit_package.sponsored_benefits.each_with_index do |sponsored_benefit, i|
            current_sponsored_benefit = current_benefit_package.sponsored_benefits[i]
            expect(sponsored_benefit.product_package).to eq renewal_benefit_sponsor_catalog.product_packages.by_package_kind(current_sponsored_benefit.product_package_kind).by_product_kind(current_sponsored_benefit.product_kind)[0]
          end
        end

        it "should reference to renewal_product_option_choice" do
          renewal_benefit_package.sponsored_benefits.each_with_index do |sponsored_benefit, i|
            current_sponsored_benefit = current_benefit_package.sponsored_benefits[i]
            expect(sponsored_benefit.product_option_choice).to eq current_sponsored_benefit.reference_product.renewal_product.issuer_profile_id.to_s
          end
        end

        it "should attach renewal reference product" do
          renewal_benefit_package.sponsored_benefits.each_with_index do |sponsored_benefit, i|
            current_sponsored_benefit = current_benefit_package.sponsored_benefits[i]
            expect(sponsored_benefit.reference_product).to eq current_sponsored_benefit.reference_product.renewal_product
          end
        end

        it "should renew sponsor contributions" do
          renewal_benefit_package.sponsored_benefits.each_with_index do |sponsored_benefit, i|
            expect(sponsored_benefit.sponsor_contribution).to be_present

            current_sponsored_benefit = current_benefit_package.sponsored_benefits[i]
            current_sponsored_benefit.sponsor_contribution.contribution_levels.each_with_index do |current_contribution_level, i|
              new_contribution_level = sponsored_benefit.sponsor_contribution.contribution_levels[i]
              expect(new_contribution_level.is_offered).to eq current_contribution_level.is_offered
              expect(new_contribution_level.contribution_factor).to eq current_contribution_level.contribution_factor
            end
          end
        end

        it "should renew pricing determinations" do
        end
      end

      context "when employer offering both health and dental coverages" do
        before :each do
          BenefitMarkets::Products::Product.each do |product|
            product.update_attributes!(issuer_profile_id: issuer_profile.id) unless product.issuer_profile_id
          end
        end

        let(:product_kinds)  { [:health, :dental] }
        let(:dental_sponsored_benefit) { true }

        let(:renewal_application)             { initial_application.renew }
        let(:renewal_benefit_sponsor_catalog) { renewal_application.benefit_sponsor_catalog }
        let(:renewal_bp)        { renewal_application.benefit_packages.build }

        let(:current_app) { benefit_sponsorship.benefit_applications[0] }
        let(:current_bp)  { current_app.benefit_packages[0] }

        subject do
          current_bp.renew(renewal_bp)
        end

        context "when renewal product available for both health and dental" do

          let(:health_sb) { current_bp.sponsored_benefit_for(:health) }
          let(:dental_sb) { current_bp.sponsored_benefit_for(:dental) }

          it "does build valid renewal benefit package" do
            expect(subject.valid?).to be_truthy
          end

          it "does renew health sponsored benefit" do
            expect(subject.sponsored_benefit_for(:health)).to be_present
          end

          it "does renew health reference product" do
            expect(subject.sponsored_benefit_for(:health).reference_product).to eq health_sb.reference_product.renewal_product
          end

          it "does renew health sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:health).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq health_sb.sponsor_contribution.contribution_levels.size
          end

          it "does renew dental sponsored benefit" do
            expect(subject.sponsored_benefit_for(:dental)).to be_present
          end

          it "does renew dental reference product" do
            expect(subject.sponsored_benefit_for(:dental).reference_product).to eq dental_sb.reference_product.renewal_product
          end

          it "does renew dental sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:dental).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq dental_sb.sponsor_contribution.contribution_levels.size
          end
        end

        context "when renewal product available for health only" do
          let!(:dental_products) do
            create_list(
              :benefit_markets_products_dental_products_dental_product,
              5,
              issuer_profile: issuer_profile,
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
              product_package_kinds: [:single_product],
              service_area: service_area,
              metal_level_kind: :dental
            )
          end

          let(:health_sb) { current_bp.sponsored_benefit_for(:health) }
          let(:dental_sb) { current_bp.sponsored_benefit_for(:dental) }

          it "does build valid renewal benefit package" do
            expect(subject.valid?).to be_truthy
          end

          it "does renew health sponsored benefit" do
            expect(subject.sponsored_benefit_for(:health)).to be_present
          end

          it "does renew health reference product" do
            expect(subject.sponsored_benefit_for(:health).reference_product).to eq health_sb.reference_product.renewal_product
          end

          it "does renew health sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:health).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq health_sb.sponsor_contribution.contribution_levels.size
          end

          it "does not renew dental sponsored benefit" do
            expect(subject.sponsored_benefit_for(:dental)).to be_blank
          end
        end

        context "when renewal product available for dental only" do
          let!(:health_products) do
            create_list(
              :benefit_markets_products_health_products_health_product,
              5,
              issuer_profile: issuer_profile,
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
              product_package_kinds: [:single_issuer, :metal_level, :single_product],
              service_area: service_area,
              metal_level_kind: :gold
            )
          end

          let(:health_sb) { current_bp.sponsored_benefit_for(:health) }
          let(:dental_sb) { current_bp.sponsored_benefit_for(:dental) }

          it "does build valid renewal benefit package" do
            expect(subject.valid?).to be_truthy
          end

          it "does not renew health sponsored benefit" do
            expect(subject.sponsored_benefit_for(:health)).to be_blank
          end

          it "does renew dental sponsored benefit" do
            expect(subject.sponsored_benefit_for(:dental)).to be_present
          end

          it "does renew dental reference product" do
            expect(subject.sponsored_benefit_for(:dental).reference_product).to eq dental_sb.reference_product.renewal_product
          end

          it "does renew dental sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:dental).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq dental_sb.sponsor_contribution.contribution_levels.size
          end
        end

        context "when renewal product not available for both health and dental" do
          let!(:health_products) do
            create_list(
              :benefit_markets_products_health_products_health_product,
              5,
              issuer_profile: issuer_profile,
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
              product_package_kinds: [:single_issuer, :metal_level, :single_product],
              service_area: service_area,
              metal_level_kind: :gold
            )
          end

          let!(:dental_products) do
            create_list(
              :benefit_markets_products_dental_products_dental_product,
              5,
              issuer_profile: issuer_profile,
              application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year),
              product_package_kinds: [:single_product],
              service_area: service_area,
              metal_level_kind: :dental
            )
          end

          let(:health_sb) { current_bp.sponsored_benefit_for(:health) }
          let(:dental_sb) { current_bp.sponsored_benefit_for(:dental) }

          it "does build valid renewal benefit package" do
            expect(subject.valid?).to be_truthy
          end

          it "does not renew health sponsored benefit" do
            expect(subject.sponsored_benefit_for(:health)).to be_blank
          end

          it "does not renew dental sponsored benefit" do
            expect(subject.sponsored_benefit_for(:dental)).to be_blank
          end
        end

        context "when employer has conversion dental sponsored benefit" do

          let(:health_sb) { current_bp.sponsored_benefit_for(:health) }
          let(:dental_sb) { current_bp.sponsored_benefits.unscoped.detect{|sb| sb.product_kind == :dental } }

          before do
            dental_sb.update(source_kind: :conversion)
            current_bp.reload
          end

          it "does build valid renewal benefit package" do
            expect(subject.valid?).to be_truthy
          end

          it "does renew health sponsored benefit" do
            expect(subject.sponsored_benefit_for(:health)).to be_present
          end

          it "does renew health reference product" do
            expect(subject.sponsored_benefit_for(:health).reference_product).to eq health_sb.reference_product.renewal_product
          end

          it "does renew health sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:health).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq health_sb.sponsor_contribution.contribution_levels.size
          end

          it "does renew dental sponsored benefit" do
            expect(dental_sb.source_kind).to eq :conversion
            expect(subject.sponsored_benefit_for(:dental)).to be_present
            expect(subject.sponsored_benefit_for(:dental).source_kind).to eq :benefit_sponsor_catalog
          end

          it "does renew dental reference product" do
            expect(subject.sponsored_benefit_for(:dental).reference_product).to eq dental_sb.reference_product.renewal_product
          end

          it "does renew dental sponsor contributions" do
            sponsor_contribution = subject.sponsored_benefit_for(:dental).sponsor_contribution
            expect(sponsor_contribution).to be_present
            expect(sponsor_contribution.contribution_levels.size).to eq dental_sb.sponsor_contribution.contribution_levels.size
          end
        end
      end
    end

    describe '.renew_member_benefit' do
      include_context "setup renewal application"

      let(:renewed_enrollment) { double("hbx_enrollment")}
      let(:ra) {renewal_application}
      let(:ia) {predecessor_application}
      let(:bs) { ra.predecessor.benefit_sponsorship}
      let(:cbp){ra.predecessor.benefit_packages.first}
      let(:rbp){ra.benefit_packages.first}
      let!(:rhsb) do
        sb = rbp.health_sponsored_benefit
        sb.product_package_kind = :single_product
        sb.save
        sb
      end
      let(:ibp){ia.benefit_packages.first}
      let(:roster_size) { 5 }
      let(:enrollment_kinds) { ['health'] }
      let!(:census_employees) { create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: bs, employer_profile: bs.profile, benefit_group: cbp) }
      let!(:person) { FactoryBot.create(:person) }
      let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
      let!(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, person: person)}
      let!(:census_employee) { census_employees.first }
      let(:active_bga) {FactoryBot.build(:benefit_sponsors_benefit_group_assignment, benefit_group: ibp, census_employee: census_employee, is_active: true)}
      let(:renewal_bga) {FactoryBot.build(:benefit_sponsors_benefit_group_assignment, benefit_group: rbp, census_employee: census_employee, is_active: false)}

      let!(:census_update) do
        census_employee.benefit_group_assignments = [active_bga, renewal_bga]
        census_employee.save!
      end
      let(:hbx_enrollment) do
        FactoryBot.create(:hbx_enrollment, :shop,
                          household: family.active_household,
                          product: cbp.sponsored_benefits.first.reference_product,
                          coverage_kind: :health,
                          effective_on: predecessor_application.start_on,
                          employee_role_id: census_employee.employee_role.id,
                          sponsored_benefit_package_id: cbp.id,
                          benefit_sponsorship: bs,
                          benefit_group_assignment: active_bga)
      end


      let(:renewal_product_package)    { renewal_benefit_market_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
      let(:product) { renewal_product_package.products[0] }

      let!(:update_product) do
        reference_product = current_benefit_package.sponsored_benefits.first.reference_product
        reference_product.renewal_product = product
        reference_product.save!
      end

      let(:active_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: ibp, census_employee: census_employee)}
      let(:renewal_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: rbp, census_employee: census_employee)}

      let!(:census_update) do
        census_employee.benefit_group_assignments = [active_bga, renewal_bga]
        census_employee.save!
      end

      let(:hbx_enrollment) do
        create(
          :hbx_enrollment,
          :shop,
          household: family.active_household,
          product: cbp.sponsored_benefits.first.reference_product,
          coverage_kind: :health,
          effective_on: predecessor_application.start_on,
          employee_role_id: census_employee.employee_role.id,
          sponsored_benefit_package_id: cbp.id,
          benefit_sponsorship: bs,
          benefit_group_assignment: active_bga
        )
      end

      before do
        allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
        census_employee.update_attributes(employee_role_id: employee_role.id)
        census_employee.employee_role.primary_family.active_household.hbx_enrollments << hbx_enrollment
        census_employee.employee_role.primary_family.save
        predecessor_application.update_attributes({:aasm_state => "active"})
        ra.update_attributes({:aasm_state => "enrollment_eligible"})
        hbx_enrollment.benefit_group_assignment_id = census_employee.benefit_group_assignments[0].id
        allow(rbp).to receive(:trigger_renewal_model_event).and_return nil
      end

      it "should have renewing enrollment" do
        expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ["coverage_selected"]
        rbp.renew_member_benefit(census_employee)
        family.reload
        expect(family.active_household.hbx_enrollments.map(&:aasm_state).include?("auto_renewing")).to eq true
      end

      it "when enrollment in terminated for initial application, should not generate renewal" do
        hbx_enrollment.update_attributes(benefit_sponsorship: bs, aasm_state: 'coverage_terminated')
        hbx_enrollment.save

        expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ["coverage_terminated"]
        rbp.renew_member_benefit(census_employee)
        family.reload
        expect(family.active_household.hbx_enrollments.map(&:aasm_state).include?("auto_renewing")).to eq false
      end

      it "when enrollment in employee_termination_pending for initial application, should not generate renewal" do
        hbx_enrollment.update_attributes(benefit_sponsorship: bs, aasm_state: 'coverage_termination_pending')
        hbx_enrollment.save

        expect(family.active_household.hbx_enrollments.map(&:aasm_state)).to eq ["coverage_termination_pending"]
        rbp.renew_member_benefit(census_employee)
        family.reload
        expect(family.active_household.hbx_enrollments.map(&:aasm_state).include?("auto_renewing")).to eq false
      end
    end

    describe '.is_renewal_benefit_available?' do

      let(:renewal_product_package)    { renewal_benefit_market_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
      let(:product) { renewal_product_package.products[0] }
      let(:reference_product) { current_benefit_package.sponsored_benefits[0].reference_product }
      let(:current_enrolled_product) { product_package.products[2] }

      let!(:update_product) do
        reference_product.renewal_product = product
        reference_product.save!
      end

      let(:renewal_benefit_sponsor_catalog) { benefit_sponsorship.benefit_sponsor_catalog_for(renewal_effective_date) }
      let!(:renewal_application)             { initial_application.renew }
      let(:renewal_benefit_package)         { renewal_application.benefit_packages.build }

      context "when renewal product missing" do
        let(:hbx_enrollment) { double(product: current_enrolled_product, is_coverage_waived?: false, coverage_termination_pending?: false, coverage_kind: :health) }
        let(:renewal_sponsored_benefit) do
          renewal_benefit_package.sponsored_benefits.build(
            product_package_kind: :single_issuer
          )
        end

        before do
          #removing hbx_enrollment.product.renewal_product from renewal_product_package
          allow(renewal_sponsored_benefit).to receive(:products).and_return(renewal_product_package.products.reject{ |prod| prod.id == hbx_enrollment.product.renewal_product.id })
          allow(current_enrolled_product).to receive(:renewal_product).and_return(nil)
          allow(renewal_benefit_package).to receive(:sponsored_benefit_for).and_return(renewal_sponsored_benefit)
        end

        it 'should return false' do
          expect(renewal_benefit_package.is_renewal_benefit_available?(hbx_enrollment)).to be_falsey
        end
      end

      context 'can_renew?' do
        let(:hbx_enrollment) { double(product: current_benefit_package.sponsored_benefits.first.reference_product, coverage_kind: :health, is_coverage_waived?: false, coverage_termination_pending?: false) }
        let(:sponsored_benefit) { renewal_benefit_package.sponsored_benefits.build(product_package_kind: :single_issuer) }
        let(:renewal_product) { create(:benefit_markets_products_product) }

        before do
          allow(sponsored_benefit).to receive(:products).and_return(renewal_product_package.products)
          allow(renewal_benefit_package).to receive(:sponsored_benefit_for).and_return(sponsored_benefit)
        end

        it 'should return false if renewal product is not present' do
          allow_any_instance_of(BenefitSponsors::SponsoredBenefits::SponsoredBenefit).to receive(:renewal_product).and_return(nil)
          expect(renewal_benefit_package.can_renew?).to be_falsey
        end

        it 'should return false if renewal product is present and its rates are not present' do
          allow_any_instance_of(BenefitSponsors::SponsoredBenefits::SponsoredBenefit).to receive(:renewal_product).and_return(renewal_product)
          expect(renewal_benefit_package.can_renew?).to be_falsey
        end

        it 'should return false if renewal product is present and its rates are not present' do
          allow_any_instance_of(BenefitSponsors::SponsoredBenefits::SponsoredBenefit).to receive(:renewal_product).and_return(renewal_product)
          allow(renewal_benefit_package).to receive(:renewal_date).and_return(renewal_product.application_period.min)
          expect(renewal_benefit_package.can_renew?).to be_truthy
        end
      end

      context "when renewal product offered by employer" do
        let(:hbx_enrollment) { double(product: current_benefit_package.sponsored_benefits.first.reference_product, coverage_kind: :health, is_coverage_waived?: false, coverage_termination_pending?: false) }
        let(:sponsored_benefit) { renewal_benefit_package.sponsored_benefits.build(product_package_kind: :single_issuer) }

        before do
          allow(sponsored_benefit).to receive(:products).and_return(renewal_product_package.products)
          allow(renewal_benefit_package).to receive(:sponsored_benefit_for).and_return(sponsored_benefit)
        end

        it 'should return true' do
          expect(renewal_benefit_package.is_renewal_benefit_available?(hbx_enrollment)).to be_truthy
        end
      end

      context "when renewal product not offered by employer" do
        let(:product) {FactoryBot.create(:benefit_markets_products_health_products_health_product, :with_issuer_profile)}
        let(:hbx_enrollment) { double(product: current_benefit_package.sponsored_benefits.first.reference_product, coverage_kind: :health, is_coverage_waived?: false, coverage_termination_pending?: false) }
        let(:sponsored_benefit) { renewal_benefit_package.sponsored_benefits.build(product_package_kind: :single_issuer) }

        before do
          allow(sponsored_benefit).to receive(:products).and_return(renewal_product_package.products)
          allow(renewal_benefit_package).to receive(:sponsored_benefit_for).and_return(sponsored_benefit)
        end

        it "should return false" do
          expect(renewal_benefit_package.is_renewal_benefit_available?(hbx_enrollment)).to be_falsey
        end
      end
    end

    describe '.sponsored_benefit_for' do
    end

    describe '.assigned_census_employees_on' do
    end

    describe '.renew_employee_benefits' do
      include_context "setup employees with benefits"

    end

    describe 'changing reference product' do
      context 'changing reference product' do
        include_context "setup benefit market with market catalogs and product packages"
        include_context "setup initial benefit application"

        let(:sponsored_benefit) { initial_application.benefit_packages.first.sponsored_benefits.first }
        let(:new_reference_product) { product_package.products[2] }

        before do
          @benefit_application_id = sponsored_benefit.benefit_package.benefit_application.id
          sponsored_benefit.reference_product_id = new_reference_product._id
          sponsored_benefit.save!
        end

        it 'changes to the correct product' do
          bs = ::BenefitSponsors::BenefitSponsorships::BenefitSponsorship.benefit_application_find([@benefit_application_id]).first
          benefit_application_from_db = bs.benefit_applications.detect { |ba| ba.id == @benefit_application_id }
          expect(sponsored_benefit.reference_product).to eq(new_reference_product)
          sponsored_benefit_from_db = benefit_application_from_db.benefit_packages.first.sponsored_benefits.first
          expect(sponsored_benefit_from_db.id).to eq(sponsored_benefit.id)
          expect(sponsored_benefit_from_db.reference_product).to eq(new_reference_product)
        end
      end
    end

    describe '.reinstate_canceled_member_benefits' do

      context 'when application got canceled due to ineligble state' do


        context 'given employee coverages got canceled after application cancellation' do

          it 'should reinstate their canceled coverages' do
          end
        end

        context 'given employee coverages got canceled before application cancellation' do

          it 'should not reinstate their canceled coverages' do
          end
        end
      end

      context 'when application not canceled due to ineligble state' do

        it 'should not process any reinstatements on enrollments' do
        end
      end
    end

    describe '.terminate_member_benefits', :dbclean => :after_each do

      include_context "setup initial benefit application" do
        let(:current_effective_date) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
      end

      let(:benefit_package)  { initial_application.benefit_packages.first }
      let(:benefit_group_assignment) {FactoryBot.build(:benefit_group_assignment, benefit_group: benefit_package)}
      let(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, person: person, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee.id) }
      let(:census_employee) do
        FactoryBot.create(:census_employee,
                          employer_profile: benefit_sponsorship.profile,
                          benefit_sponsorship: benefit_sponsorship,
                          benefit_group_assignments: [benefit_group_assignment])
      end
      let(:person)       { FactoryBot.create(:person, :with_family) }
      let!(:family)       { person.primary_family }
      let!(:hbx_enrollment) do
        hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                           household: family.active_household,
                                           aasm_state: "coverage_selected",
                                           effective_on: initial_application.start_on,
                                           rating_area_id: initial_application.recorded_rating_area_id,
                                           sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                           sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                           benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                           employee_role_id: employee_role.id)
        hbx_enrollment.benefit_sponsorship = benefit_sponsorship
        hbx_enrollment.save!
        hbx_enrollment
      end

      let(:benefit_group_assignment_1) {FactoryBot.build(:benefit_group_assignment, benefit_group: benefit_package)}
      let(:employee_role_1) { FactoryBot.create(:benefit_sponsors_employee_role, person: person_1, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee_1.id) }
      let(:census_employee_1) do
        FactoryBot.create(:census_employee,
                          employer_profile: benefit_sponsorship.profile,
                          benefit_sponsorship: benefit_sponsorship,
                          benefit_group_assignments: [benefit_group_assignment_1])
      end
      let(:person_1)       { FactoryBot.create(:person, :with_family) }
      let!(:family_1)       { person_1.primary_family }
      let!(:hbx_enrollment_1) do
        hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                           household: family_1.active_household,
                                           aasm_state: "coverage_selected",
                                           effective_on: TimeKeeper.date_of_record.next_month,
                                           rating_area_id: initial_application.recorded_rating_area_id,
                                           sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                           sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                           benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                           employee_role_id: employee_role_1.id)
        hbx_enrollment.benefit_sponsorship = benefit_sponsorship
        hbx_enrollment.save!
        hbx_enrollment
      end

      let(:end_on) { TimeKeeper.date_of_record.prev_month }

      context "when coverage_selected enrollments are present", :dbclean => :after_each do

        before do
          initial_application.update_attributes!(aasm_state: :terminated)
          initial_application.benefit_application_items.create(effective_period: initial_application.start_on..end_on, state: :terminated, sequence_id: 1)
          benefit_package.terminate_member_benefits
          hbx_enrollment.reload
          hbx_enrollment_1.reload
        end

        it 'should move valid enrollments to terminated state' do
          expect(hbx_enrollment.aasm_state).to eq "coverage_terminated"
        end

        it 'should update terminated_on field on hbx_enrollment' do
          expect(hbx_enrollment.terminated_on).to eq initial_application.end_on
        end

        it 'should move future enrollments on family_1 to canceled state' do
          expect(hbx_enrollment_1.aasm_state).to eq "coverage_canceled"
        end
      end

      context 'when multiple active enrollments exists on a family' do
        let!(:current_enrollment) do
          hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                             household: family.active_household,
                                             aasm_state: "coverage_termination_pending",
                                             terminated_on: TimeKeeper.date_of_record.next_month.end_of_month,
                                             effective_on: initial_application.start_on,
                                             rating_area_id: initial_application.recorded_rating_area_id,
                                             sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                             sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                             benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                             employee_role_id: employee_role.id)
          hbx_enrollment.benefit_sponsorship = benefit_sponsorship
          hbx_enrollment.save!
          hbx_enrollment
        end

        let!(:future_enrollment) do
          hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                             household: family.active_household,
                                             aasm_state: "inactive",
                                             effective_on: TimeKeeper.date_of_record.next_month.beginning_of_month,
                                             rating_area_id: initial_application.recorded_rating_area_id,
                                             sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                             sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                             benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                             employee_role_id: employee_role.id)
          hbx_enrollment.benefit_sponsorship = benefit_sponsorship
          hbx_enrollment.save!
          hbx_enrollment
        end

        before do
          initial_application.update_attributes!(aasm_state: :terminated)
          initial_application.benefit_application_items.create(effective_period: initial_application.start_on..end_on, state: :terminated, sequence_id: 1)
          benefit_package.terminate_member_benefits
          current_enrollment.reload
          future_enrollment.reload
        end

        it 'should terminate current_enrollment' do
          expect(current_enrollment.aasm_state).to eq "coverage_terminated"
        end

        it 'should update terminated_on on current_enrollment' do
          expect(current_enrollment.terminated_on).to eq initial_application.end_on
        end

        it 'should move future enrollment to canceled state' do
          expect(future_enrollment.aasm_state).to eq "coverage_canceled"
        end
      end

      context "when an employee has coverage_termination_pending enrollment", :dbclean => :after_each do

        let(:hbx_enrollment_terminated_on) { end_on.prev_month }

        before do
          initial_application.update_attributes!(aasm_state: :terminated)
          initial_application.benefit_application_items.create(effective_period: initial_application.start_on..end_on, state: :terminated, sequence_id: 1)
          hbx_enrollment.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_termination_pending", terminated_on: hbx_enrollment_terminated_on)
          hbx_enrollment_1.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_termination_pending", terminated_on: end_on + 2.months)
          benefit_package.terminate_member_benefits
          hbx_enrollment.reload
          hbx_enrollment_1.reload
        end

        it "should not update hbx_enrollment terminated_on if terminated_on < benefit_application end on" do
          expect(hbx_enrollment.terminated_on).to eq hbx_enrollment_terminated_on
          expect(hbx_enrollment.terminated_on).not_to eq end_on
        end

        it "should update hbx_enrollment terminated_on if terminated_on > benefit_application end on" do
          expect(hbx_enrollment_1.terminated_on).to eq end_on
        end

        context 'when term date matches application end date' do
          let(:hbx_enrollment_terminated_on) { end_on.prev_month }
          let!(:transitions_count) { hbx_enrollment.workflow_state_transitions.size }

          it "should not update hbx_enrollment transitions" do
            expect(hbx_enrollment.reload.workflow_state_transitions.size).to eq transitions_count
            expect(hbx_enrollment.aasm_state).to eq 'coverage_termination_pending'
          end
        end
      end

      context "when an employee has coverage_terminated enrollment", :dbclean => :after_each do

        let(:hbx_enrollment_terminated_on) { end_on.prev_month }

        before do
          initial_application.update_attributes!(aasm_state: :terminated)
          initial_application.benefit_application_items.create(effective_period: initial_application.start_on..end_on, state: :terminated, sequence_id: 1)
          hbx_enrollment.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_terminated", terminated_on: hbx_enrollment_terminated_on)
          hbx_enrollment_1.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_terminated", terminated_on: end_on + 2.months)
          benefit_package.terminate_member_benefits
          hbx_enrollment.reload
          hbx_enrollment_1.reload
        end

        it "should update terminated_on date on enrollment if terminated_on > benefit_application end_on" do
          expect(hbx_enrollment_1.terminated_on).to eq end_on
        end

        it "should NOT update terminated_on date on enrollment if terminated_on < benefit_application end_on" do
          expect(hbx_enrollment.terminated_on).to eq hbx_enrollment_terminated_on
        end
      end

      context "terminate_benefit_group_assignments", :dbclean => :after_each do

        before :each do
          @bga = initial_application.benefit_sponsorship.census_employees.first.benefit_group_assignments.first
          @bga.update_attributes!(end_on: benefit_package.end_on)
        end

        it "should update benefit_group_assignment end_on if end_on < benefit_application end on" do
          benefit_package.terminate_benefit_group_assignments
          expect(benefit_package.end_on).to eq @bga.end_on
        end
      end
    end

    describe '.cancel_member_benefits' do
      include_context "setup renewal application"

      let(:renewed_enrollment) { double("hbx_enrollment")}
      let(:ra) {renewal_application}
      let(:ia) {predecessor_application}
      let(:bs) { ra.predecessor.benefit_sponsorship}
      let(:cbp){ra.predecessor.benefit_packages.first}
      let(:rbp){ra.benefit_packages.first}
      let(:ibp){ia.benefit_packages.first}
      let(:roster_size) { 5 }
      let!(:census_employees) { create_list(:census_employee, roster_size, :with_active_assignment, benefit_sponsorship: bs, employer_profile: bs.profile, benefit_group: cbp) }
      let!(:person) { FactoryBot.create(:person) }
      let!(:family) {FactoryBot.create(:family, :with_primary_family_member, person: person)}
      let!(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, person: person)}
      let!(:census_employee) { census_employees.first }
      let(:active_bga) {FactoryBot.build(:benefit_sponsors_benefit_group_assignment, benefit_group: ibp, census_employee: census_employee, is_active: true)}
      let(:renewal_bga) {FactoryBot.build(:benefit_sponsors_benefit_group_assignment, benefit_group: rbp, census_employee: census_employee, is_active: false)}

      let!(:census_update) do
        census_employee.benefit_group_assignments = [active_bga, renewal_bga]
        census_employee.save!
      end
      let(:hbx_enrollment) do
        FactoryBot.create(:hbx_enrollment, :shop,
                          household: family.active_household,
                          product: cbp.sponsored_benefits.first.reference_product,
                          coverage_kind: :health,
                          effective_on: predecessor_application.start_on,
                          employee_role_id: census_employee.employee_role.id,
                          sponsored_benefit_package_id: cbp.id,
                          benefit_sponsorship: bs,
                          benefit_group_assignment: active_bga)
      end


      let(:renewal_product_package)    { renewal_benefit_market_catalog.product_packages.detect { |package| package.package_kind == package_kind } }
      let(:product) { renewal_product_package.products[0] }

      let!(:update_product) do
        reference_product = current_benefit_package.sponsored_benefits.first.reference_product
        reference_product.renewal_product = product
        reference_product.save!
      end

      let(:active_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: ibp, census_employee: census_employee)}
      let(:renewal_bga) {build(:benefit_sponsors_benefit_group_assignment, benefit_group: rbp, census_employee: census_employee)}

      let!(:census_update) do
        census_employee.benefit_group_assignments = [active_bga, renewal_bga]
        census_employee.save!
      end

      let(:hbx_enrollment) do
        create(
          :hbx_enrollment,
          :shop,
          household: family.active_household,
          product: cbp.sponsored_benefits.first.reference_product,
          coverage_kind: :health,
          effective_on: predecessor_application.start_on,
          employee_role_id: census_employee.employee_role.id,
          sponsored_benefit_package_id: cbp.id,
          benefit_sponsorship: bs,
          benefit_group_assignment: active_bga
        )
      end

      before do
        allow_any_instance_of(BenefitSponsors::Factories::EnrollmentRenewalFactory).to receive(:has_renewal_product?).and_return(true)
        census_employee.update_attributes(employee_role_id: employee_role.id)
        census_employee.employee_role.primary_family.active_household.hbx_enrollments << hbx_enrollment
        census_employee.employee_role.primary_family.save
        predecessor_application.update_attributes({:aasm_state => "active"})
        ra.update_attributes({:aasm_state => "enrollment_eligible"})
        hbx_enrollment.benefit_group_assignment_id = census_employee.benefit_group_assignments[0].id
        allow(rbp).to receive(:trigger_renewal_model_event).and_return nil
      end

      it "should not assign a new package to inactive census employees" do
        census_employees.first.update_attributes!(aasm_state: 'employment_terminated')
        census_employees.each do |ce|
          ce.renewal_benefit_group_assignment.update_attributes!(is_active: true)
        end
        rbp.benefit_application.benefit_packages << cbp

        rbp.cancel_member_benefits(delete_benefit_package: true)
        expect(rbp.is_active).to eq false
        expect(census_employees.first.renewal_benefit_group_assignment).to eq nil
      end
    end

    describe '.expire_member_benefits', :dbclean => :after_each do

      include_context "setup initial benefit application" do
        let(:current_effective_date) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
      end

      let(:benefit_package)  { initial_application.benefit_packages.first }
      let(:benefit_group_assignment) {FactoryBot.build(:benefit_group_assignment, benefit_group: benefit_package)}
      let(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, person: person, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee.id) }
      let(:census_employee) do
        FactoryBot.create(:census_employee,
                          employer_profile: benefit_sponsorship.profile,
                          benefit_sponsorship: benefit_sponsorship,
                          benefit_group_assignments: [benefit_group_assignment])
      end
      let(:person)       { FactoryBot.create(:person, :with_family) }
      let!(:family)       { person.primary_family }
      let!(:hbx_enrollment) do
        hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                           household: family.active_household,
                                           aasm_state: "coverage_selected",
                                           effective_on: initial_application.start_on,
                                           rating_area_id: initial_application.recorded_rating_area_id,
                                           sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                           sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                           benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                           employee_role_id: employee_role.id)
        hbx_enrollment.benefit_sponsorship = benefit_sponsorship
        hbx_enrollment.save!
        hbx_enrollment
      end

      let(:end_on) { TimeKeeper.date_of_record.prev_month }

      context "when coverage_selected enrollments are present", :dbclean => :after_each do

        before do
          initial_application.update_attributes!(aasm_state: :expired)
          initial_application.benefit_application_items.create(
            effective_period: initial_application.start_on..end_on,
            sequence_id: 1,
            state: :expired
          )
          benefit_package.expire_member_benefits
          hbx_enrollment.reload
        end

        it 'should move valid enrollments to expired state' do
          expect(hbx_enrollment.aasm_state).to eq "coverage_expired"
        end

      end

      context "when coverage_selected enrollments linked to conversion sponsored benefit", :dbclean => :after_each do

        let(:hbx_enrollment_terminated_on) { end_on.prev_month }

        before do
          initial_application.update_attributes!(aasm_state: :expired)
          initial_application.benefit_application_items.create(
            effective_period: initial_application.start_on..end_on,
            sequence_id: 1,
            state: :expired
          )
          benefit_package.health_sponsored_benefit.update_attributes(source_kind: :conversion)
          initial_application.reload
          benefit_package.expire_member_benefits
          hbx_enrollment.reload
        end

        it 'should move enrollments that linked with conversion sponsored benefit to expired state' do
          expect(benefit_package.sponsored_benefits.unscoped.first.source_kind).to eq :conversion
          expect(hbx_enrollment.aasm_state).to eq "coverage_expired"
        end
      end
    end

    describe '.termination_pending_member_benefits' do

      include_context "setup initial benefit application" do
        let(:current_effective_date) { (TimeKeeper.date_of_record - 2.months).beginning_of_month }
      end

      let(:benefit_package)  { initial_application.benefit_packages.first }
      let(:benefit_group_assignment) {FactoryBot.build(:benefit_group_assignment, benefit_group: benefit_package)}
      let(:employee_role) { FactoryBot.create(:benefit_sponsors_employee_role, person: person, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee.id) }
      let(:census_employee) do
        FactoryBot.create(:census_employee,
                          employer_profile: benefit_sponsorship.profile,
                          benefit_sponsorship: benefit_sponsorship,
                          benefit_group_assignments: [benefit_group_assignment])
      end
      let(:person)       { FactoryBot.create(:person, :with_family) }
      let!(:family)       { person.primary_family }
      let!(:hbx_enrollment) do
        hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                           household: family.active_household,
                                           aasm_state: "coverage_selected",
                                           effective_on: initial_application.start_on,
                                           rating_area_id: initial_application.recorded_rating_area_id,
                                           sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                           sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                           benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                           employee_role_id: employee_role.id)
        hbx_enrollment.benefit_sponsorship = benefit_sponsorship
        hbx_enrollment.save!
        hbx_enrollment
      end

      let(:employee_role_1) { FactoryBot.create(:benefit_sponsors_employee_role, person: person_1, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee_1.id) }
      let(:census_employee_1) do
        FactoryBot.create(:census_employee,
                          employer_profile: benefit_sponsorship.profile,
                          benefit_sponsorship: benefit_sponsorship,
                          benefit_group_assignments: [benefit_group_assignment])
      end
      let!(:benefit_group_assignment_1) {FactoryBot.create(:benefit_group_assignment, benefit_group: benefit_package, census_employee: census_employee_1)}
      let(:person_1)       { FactoryBot.create(:person, :with_family) }
      let!(:family_1)       { person_1.primary_family }
      let!(:hbx_enrollment_1) do
        hbx_enrollment = FactoryBot.create(:hbx_enrollment, :with_enrollment_members, :with_product,
                                           household: family_1.active_household,
                                           aasm_state: "coverage_selected",
                                           effective_on: initial_application.start_on,
                                           rating_area_id: initial_application.recorded_rating_area_id,
                                           sponsored_benefit_id: initial_application.benefit_packages.first.health_sponsored_benefit.id,
                                           sponsored_benefit_package_id: initial_application.benefit_packages.first.id,
                                           benefit_sponsorship_id: initial_application.benefit_sponsorship.id,
                                           employee_role_id: employee_role_1.id)
        hbx_enrollment.benefit_sponsorship = benefit_sponsorship
        hbx_enrollment.save!
        hbx_enrollment
      end

      let(:end_on) { TimeKeeper.date_of_record.next_month }

      before do
        initial_application.update_attributes!(aasm_state: :termination_pending)
        initial_application.benefit_application_items.create(
          effective_period: initial_application.start_on..end_on,
          sequence_id: 1,
          state: :termination_pending
        )
        benefit_package.termination_pending_member_benefits
        hbx_enrollment.reload
      end

      it 'should move valid enrollments to termination pending state' do
        expect(hbx_enrollment.aasm_state).to eq "coverage_termination_pending"
      end

      it 'should update terminated_on field on hbx_enrollment' do
        expect(hbx_enrollment.terminated_on).to eq initial_application.end_on
      end

      context "when an employee has coverage_termination_pending enrollment", :dbclean => :after_each do

        let(:hbx_enrollment_terminated_on) { end_on.prev_month }

        before do
          initial_application.update_attributes!(aasm_state: :termination_pending)
          initial_application.benefit_application_items.create(
            effective_period: initial_application.start_on..end_on,
            sequence_id: 1,
            state: :termination_pending
          )
          hbx_enrollment.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_termination_pending", terminated_on: hbx_enrollment_terminated_on)
          hbx_enrollment_1.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_termination_pending", terminated_on: end_on + 2.months)
          benefit_package.termination_pending_member_benefits
          hbx_enrollment.reload
          hbx_enrollment_1.reload
        end

        it "should not update hbx_enrollment terminated_on if terminated_on < benefit_application end on" do
          expect(hbx_enrollment.terminated_on).to eq hbx_enrollment_terminated_on
          expect(hbx_enrollment.terminated_on).not_to eq end_on
        end

        it "should update hbx_enrollment terminated_on if terminated_on > benefit_application end on" do
          expect(hbx_enrollment_1.terminated_on).to eq end_on
        end

        context 'when term date matches application end date' do
          let(:hbx_enrollment_terminated_on) { end_on.prev_month }
          let!(:transitions_count) { hbx_enrollment.workflow_state_transitions.size }

          it "should not update hbx_enrollment transitions" do
            expect(hbx_enrollment.reload.workflow_state_transitions.size).to eq transitions_count
            expect(hbx_enrollment.aasm_state).to eq 'coverage_termination_pending'
          end
        end
      end

      context "pending terminate_benefit_group_assignments", :dbclean => :after_each do
        before :each do
          @bga = initial_application.benefit_sponsorship.census_employees.first.benefit_group_assignments.first
          @bga.update_attributes!(end_on: nil)
        end

        it "should update benefit_group_assignment end_on if end_on > benefit_application end on" do
          expect(@bga.end_on).to eq nil
          benefit_package.terminate_benefit_group_assignments
          expect(@bga.end_on).to eq benefit_package.end_on
        end
      end

      context "when an employee has coverage_terminated enrollment", :dbclean => :after_each do

        let(:hbx_enrollment_terminated_on) { end_on.prev_month }

        before do
          initial_application.update_attributes!(aasm_state: :termination_pending)
          initial_application.benefit_application_items.create(
            effective_period: initial_application.start_on..end_on,
            sequence_id: 1,
            state: :termination_pending
          )
          hbx_enrollment.update_attributes!(effective_on: initial_application.start_on, aasm_state: "coverage_terminated", terminated_on: hbx_enrollment_terminated_on)
          benefit_package.termination_pending_member_benefits
          hbx_enrollment.reload
        end

        it "should NOT update terminated_on date on enrollment if terminated_on < benefit_application end_on" do
          expect(hbx_enrollment.terminated_on).to eq hbx_enrollment_terminated_on
        end
      end
    end
  end
end
