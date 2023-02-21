# frozen_string_literal: true

require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

feature "Insured::MembersSelectionController GET new", :type => :feature, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup employees with benefits"

  given!(:ce) { benefit_sponsorship.census_employees.first }
  given!(:ee_person) { FactoryGirl.create(:person, :with_employee_role, :with_family, first_name: ce.first_name, last_name: ce.last_name, dob: ce.dob, ssn: ce.ssn, gender: ce.gender) }
  given!(:user) { FactoryGirl.create(:user, :person => ee_person)}
  given!(:employee_role) do
    ee_person.employee_roles.first.update_attributes!(employer_profile: abc_profile)
    ee_person.employee_roles.first
  end
  given!(:family) { ee_person.primary_family }
  given!(:primary_family_member) { family.primary_family_member }
  given!(:coverage_household) { family.active_household.immediate_family_coverage_household }
  given!(:today) { Date.today }
  given!(:start_date) { today.months_since(2).beginning_of_month }
  given!(:end_date) { start_date.end_of_year + today.month.month }

  given!(:one_issuer_product_package) {initial_application.benefit_sponsor_catalog.product_packages.select {|pp| pp.package_kind == :single_issuer}}
  given!(:all_products) do
    products = one_issuer_product_package.map(&:products).flatten
    products[2].update_attributes!(hios_id: '52842DC0400016-01')
    BenefitMarkets::Products::Product.all.where(id: products[2].id).first.update_attributes!(hios_id: '52842DC0400016-01')
    products[3].update_attributes!(hios_id: '52842DC0400017-01')
    BenefitMarkets::Products::Product.all.where(id: products[3].id).first.update_attributes!(hios_id: '52842DC0400016-01')
    products
  end

  given!(:all_products_update) do
    cost_counter = 50
    all_products.flatten.each do |p|
      product = BenefitMarkets::Products::Product.all.where(id: p.id).first
      product.premium_tables.each do |pt|
        pt.premium_tuples.delete_all
        pt.premium_tuples.create(age: 0, cost: cost_counter - 10)
        pt.premium_tuples.create(age: 20, cost: cost_counter)
        pt.premium_tuples.create(age: 21, cost: cost_counter + 10)
        pt.premium_tuples.create(age: 22, cost: cost_counter + 20)
        pt.premium_tuples.create(age: 23, cost: cost_counter + 30)
        pt.save!
      end
      cost_counter += 50
      product.save!
    end
  end

  background :each do
    initial_application.update_attributes(
      aasm_state: :enrollment_open,
      :fte_count => 5,
      effective_period: start_date..end_date,
      :open_enrollment_period => Range.new(Date.today, Date.today + BenefitSponsors::BenefitApplications::AcaShopApplicationEligibilityPolicy::OPEN_ENROLLMENT_DAYS_MIN)
    )

    ce.employee_role_id = employee_role.id
    ce.save
    employee_role.census_employee_id = ce.id
    ee_person.save
    sign_in user
  end

  feature 'Under open enrollment and health only offering' do
    background :each do
      visit "/families/home"
    end

    feature 'Eligible employee with one member family clicks shop for plans' do
      scenario "Redirect to members selection page and display's coverage info" do
        click_link_or_button("Shop for Plans")
        expect(find('#employer_profile_legal_name').checked?).to be_truthy
        expect(page).to have_content employee_role.employer_profile.legal_name.capitalize
        expect(page).to have_content start_date.to_s

        within("#family_member_id_#{primary_family_member.id}") do
          expect(page).to have_content ee_person.first_name
          expect(page).to have_content "Health Coverage"
          expect(find("#health_enroll_primary").checked?).to be_truthy
          expect(page).not_to have_content "Dental Coverage"
        end
      end
    end

    feature "Eligible employee with ineligible dependent clicks shop for plans" do
      given!(:dependent) { FactoryGirl.create(:person) }
      given!(:family_member) { FactoryGirl.create(:family_member, family: family,person: dependent)}
      given!(:coverage_household_member) { coverage_household.coverage_household_members.create(:family_member_id => family_member.id) }

      background(:each) do
        click_link_or_button("Shop for Plans")
      end

      scenario "Redirect to members selection page - display's employee and dependent coverage info" do
        expect(find('#employer_profile_legal_name').checked?).to be_truthy
        expect(page).to have_content employee_role.employer_profile.legal_name.capitalize
        expect(page).to have_content start_date.to_s

        within("#family_member_id_#{primary_family_member.id}") do
          expect(page).to have_content ee_person.first_name
          expect(page).not_to have_content "Dental Coverage"

          within("#family_member_id_#{primary_family_member.id}_health") do
            expect(page).to have_content "Health Coverage"
            expect(find("#health_enroll_primary").checked?).to be_truthy
          end
        end

        within("#family_member_id_#{family_member.id}") do
          expect(page).to have_content dependent.first_name
          expect(page).not_to have_content "Dental Coverage"
          expect(page).not_to have_content "Health Coverage"
        end
      end
    end
  end

  feature 'Under open enrollment with health and dental offering' do
    background :each do
      visit "/families/home"
    end

    given(:dental_sponsored_benefit) { true }
    given(:product_kinds)  { [:health, :dental] }

    feature 'Eligible employee with one member family clicks shop for plans' do
      scenario "Redirect to members selection page and display's coverage info" do
        click_link_or_button("Shop for Plans")
        expect(find('#employer_profile_legal_name').checked?).to be_truthy
        expect(page).to have_content employee_role.employer_profile.legal_name.capitalize
        expect(page).to have_content start_date.to_s

        within("#family_member_id_#{primary_family_member.id}") do
          expect(page).to have_content ee_person.first_name
          expect(page).to have_content "Health Coverage"
          expect(find("#health_enroll_primary").checked?).to be_truthy
          expect(page).to have_content "Dental Coverage"
        end
      end
    end

    feature "Eligible employee with ineligible dependent clicks shop for plans" do
      given!(:dependent) { FactoryGirl.create(:person) }
      given!(:family_member) { FactoryGirl.create(:family_member, family: family,person: dependent)}
      given!(:coverage_household_member) { coverage_household.coverage_household_members.create(:family_member_id => family_member.id) }

      background(:each) do
        click_link_or_button("Shop for Plans")
      end

      scenario "Redirect to members selection page - display's employee and dependent coverage info" do
        expect(find('#employer_profile_legal_name').checked?).to be_truthy
        expect(page).to have_content employee_role.employer_profile.legal_name.capitalize
        expect(page).to have_content start_date.to_s

        within("#family_member_id_#{primary_family_member.id}") do
          expect(page).to have_content ee_person.first_name

          within("#family_member_id_#{primary_family_member.id}_health") do
            expect(page).to have_content "Health Coverage"
            expect(find("#health_enroll_primary").checked?).to be_truthy
          end

          within("#family_member_id_#{primary_family_member.id}_dental") do
            expect(page).to have_content "Dental Coverage"
            expect(find("#dental_enroll_primary").checked?).to be_truthy
          end
        end

        within("#family_member_id_#{family_member.id}") do
          expect(page).to have_content dependent.first_name
          expect(page).not_to have_content "Dental Coverage"
          expect(page).not_to have_content "Health Coverage"
        end
      end
    end
  end
end