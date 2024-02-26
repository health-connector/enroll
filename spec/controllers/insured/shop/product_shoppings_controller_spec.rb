# frozen_string_literal: true

require 'rails_helper'
require './spec/shared_context/setup_shop_families_enrollments'

# TODO: Add negative scenarios
# TODO: Add more scenarios
RSpec.describe Insured::ProductShoppingsController, type: :controller, dbclean: :after_each do
  include_context "setup shop families enrollments"

  let!(:one_issuer_product_package) {initial_application.benefit_sponsor_catalog.product_packages.select {|pp| pp.package_kind == :single_issuer}}
  let!(:all_health_products) do
    products = one_issuer_product_package.map(&:products).flatten
    products[2].update_attributes!(hios_id: '52842DC0400016-01')
    BenefitMarkets::Products::Product.all.where(id: products[2].id).first.update_attributes!(hios_id: '52842DC0400016-01')
    products[3].update_attributes!(hios_id: '52842DC0400017-01')
    BenefitMarkets::Products::Product.all.where(id: products[3].id).first.update_attributes!(hios_id: '52842DC0400017-01')
    products
  end

  let!(:dental_product_package) {initial_application.benefit_sponsor_catalog.product_packages.select {|pp| pp.package_kind == :single_product && pp.product_kind == :dental}}
  let!(:all_dental_products) do
    products = dental_product_package.map(&:products).flatten
    products[2].update_attributes!(hios_id: '32842DC0400016-01')
    BenefitMarkets::Products::Product.all.where(id: products[2].id).first.update_attributes!(hios_id: '32842DC0400016-01')
    products[3].update_attributes!(hios_id: '32842DC0400017-01')
    BenefitMarkets::Products::Product.all.where(id: products[3].id).first.update_attributes!(hios_id: '32842DC0400017-01')
    products
  end

  let!(:all_products_update) do
    cost_counter = 50
    [all_health_products + all_dental_products].flatten.each do |p|
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

  let!(:dental_sponsored_benefit) { true }
  let!(:product_kinds)  { [:health, :dental] }

  let!(:health_enrollment) do
    FactoryBot.create(:hbx_enrollment,
                       household: family.latest_household,
                       coverage_kind: 'health',
                       effective_on: initial_application.start_on,
                       enrollment_kind: "open_enrollment",
                       kind: 'employer_sponsored',
                       submitted_at: TimeKeeper.date_of_record,
                       benefit_sponsorship_id: benefit_sponsorship.id,
                       sponsored_benefit_package_id: current_benefit_package.id,
                       sponsored_benefit_id: current_benefit_package.sponsored_benefits[0].id,
                       employee_role_id: employee_role.id,
                       benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                       rating_area_id: initial_application.recorded_rating_area_id,
                       aasm_state: 'shopping')
  end

  let!(:dental_enrollment) do
    FactoryBot.create(:hbx_enrollment,
                       household: family.latest_household,
                       coverage_kind: 'dental',
                       effective_on: initial_application.start_on,
                       enrollment_kind: "open_enrollment",
                       kind: 'employer_sponsored',
                       submitted_at: TimeKeeper.date_of_record,
                       benefit_sponsorship_id: benefit_sponsorship.id,
                       sponsored_benefit_package_id: current_benefit_package.id,
                       sponsored_benefit_id: current_benefit_package.sponsored_benefits[1].id,
                       employee_role_id: employee_role.id,
                       benefit_group_assignment_id: census_employee.active_benefit_group_assignment.id,
                       rating_area_id: initial_application.recorded_rating_area_id,
                       aasm_state: 'shopping')


  end

  let!(:user) { FactoryBot.create(:user, :person => ee_person)}

  describe "GET #continuous_show" do
    context '#success' do
      let!(:params) do
        {"dental" => {"change_plan" => "", "enrollment_id" => dental_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "dental_offering" => "true", "event" => "shop_for_plans",
         "health" => {"change_plan" => "", "enrollment_id" => health_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"}, "health_offering" => "true"}
      end

      before do
        sign_in user
        get :continuous_show, params
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "context object should be success and not nil" do
        expect(assigns(:context)).not_to be_nil
        expect(assigns(:context).success?).to be_truthy
      end

      it "products present for shopping" do
        expect(assigns(:context).products.present?).to be_truthy
      end
    end

    context '#failure' do
      let!(:params) do
        {"dental" => {"change_plan" => "", "enrollment_id" => dental_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "dental_offering" => "true", "event" => "shop_for_plans",
         "health" => {"change_plan" => "", "enrollment_kind" => "", "market_kind" => "employer_sponsored"}, "health_offering" => "true"}
      end

      before do
        sign_in user
        get :continuous_show, params
      end

      it "redirects to family_account page" do
        expect(response).to redirect_to family_account_path
      end

      it "context object should be failure and not nil" do
        expect(assigns(:context).failure?).to be_truthy
      end
    end
  end

  describe "GET #thankyou" do
    context '#success' do
      let!(:params) do
        {"cart" => {"dental" => {"id" => dental_enrollment.id, "product_id" => all_dental_products.first.id},
                    "health" => {"id" => health_enrollment.id, "product_id" => all_health_products.first.id}},
         "dental" => {"change_plan" => "change_plan", "enrollment_id" => dental_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "dental_offering" => "true", "event" => "shop_for_plans",
         "health" => {"change_plan" => "change_plan", "enrollment_id" => health_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "health_offering" => "true"}
      end

      before do
        sign_in user
        get :thankyou, params
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "context object should have dental and health in cart" do
        expect(assigns(:context)).not_to be_nil
        expect(assigns(:context).key?("health")).to be_truthy
        expect(assigns(:context).key?("dental")).to be_truthy
      end
    end
  end

  describe "GET #checkout" do
    context '#success' do
      let!(:params) do
        { "dental" => {"employee_role_id" => employee_role, "enrollable" => "true", "enrollment_id" => dental_enrollment.id,
                       "enrollment_kind" => "open_enrollment", "event" => "shop_for_plans",
                       "family_id" => family.id, "market_kind" => "employer_sponsored",
                       "product_id" => all_dental_products.first.id, "use_family_deductable" => "true", "waivable" => "true"},
          "health" => {"employee_role_id" => employee_role, "enrollable" => "true", "enrollment_id" => health_enrollment.id,
                       "enrollment_kind" => "open_enrollment", "event" => "shop_for_plans",
                       "family_id" => family.id, "market_kind" => "employer_sponsored",
                       "product_id" => all_health_products.first.id, "use_family_deductable" => "true", "waivable" => "true"} }
      end

      before do
        sign_in user
        post :checkout, params
      end

      it "redirect to receipt page" do
        expect(response).to redirect_to receipt_insured_product_shoppings_path(assigns(:context))
      end

      it "context object should have dental and health in cart" do
        expect(assigns(:context)).not_to be_nil
        expect(assigns(:context).key?("health")).to be_truthy
        expect(assigns(:context).key?("dental")).to be_truthy
      end
    end
  end

  describe "GET #receipt" do
    context '#success' do
      let!(:dental_enrollment_update) { dental_enrollment.update_attributes(aasm_state: "coverage_selected", product_id: all_dental_products.first.id)}

      let!(:params) do
        {"dental" => {"can_select_coverage" => "true", "coverage_kind" => "dental", "employee_is_shopping_before_hire" => "false",
                      "enrollment_id" => dental_enrollment.id, "event" => "make_changes_for_dental", "product_id" => dental_enrollment.product_id, "qle" => "false"}}
      end

      before do
        sign_in user
        get :receipt, params
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "context object should not be empty" do
        expect(assigns(:context)).not_to be_nil
      end
    end
  end

  describe "GET #waiver_thankyou" do
    context '#success' do
      let!(:params) do
        {"dental" => {"change_plan" => "change_plan", "enrollment_id" => dental_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "dental_offering" => "true", "event" => "shop_for_plans",
         "health" => {"change_plan" => "change_plan", "enrollment_id" => health_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "health_offering" => "true"}
      end

      before do
        sign_in user
        get :waiver_thankyou, params
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "context object should have dental and health" do
        expect(assigns(:context)).not_to be_nil
        expect(assigns(:context).key?(:health)).to be_truthy
        expect(assigns(:context).key?(:dental)).to be_truthy
      end
    end

    context 'outside service area waiver reason' do
      let!(:params) do
        {"dental" => {"change_plan" => "change_plan", "enrollment_id" => dental_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored"},
         "dental_offering" => "true", "event" => "shop_for_plans",
         "health" => {"change_plan" => "change_plan", "enrollment_id" => health_enrollment.id, "enrollment_kind" => "", "market_kind" => "employer_sponsored", "waiver_reason" => "I am outside of the plan service area"},
         "health_offering" => "true"}
      end

      before do
        request.env["HTTP_REFERER"] = '/'
        sign_in user
        get :waiver_thankyou, params
      end

      context 'with admin user' do
        let!(:user) { FactoryBot.create(:user, :hbx_staff, person: ee_person)}

        it "returns http success" do
          expect(response).to have_http_status(:success)
        end
      end

      context 'without admin user' do
        let!(:user) { FactoryBot.create(:user, :person => ee_person)}

        it "returns http success" do
          expect(response).to have_http_status(:redirect)
        end
      end
    end
  end

  describe "GET #waiver_checkout" do
    context '#success' do
      let!(:params) do
        { "dental" => {"employee_role_id" => employee_role, "enrollable" => "true", "enrollment_id" => dental_enrollment.id,
                       "enrollment_kind" => "open_enrollment", "event" => "shop_for_plans",
                       "family_id" => family.id, "market_kind" => "employer_sponsored",
                       "product_id" => nil, "use_family_deductable" => "true", "waivable" => "true"},
          "health" => {"employee_role_id" => employee_role, "enrollable" => "true", "enrollment_id" => health_enrollment.id,
                       "enrollment_kind" => "open_enrollment", "event" => "shop_for_plans",
                       "family_id" => family.id, "market_kind" => "employer_sponsored",
                       "product_id" => nil, "use_family_deductable" => "true", "waivable" => "true"} }
      end

      before do
        sign_in user
        post :waiver_checkout, params
      end

      it "redirect to receipt page" do
        expect(response).to redirect_to waiver_receipt_insured_product_shoppings_path(assigns(:context))
      end

      it "context object should have dental and health in cart" do
        expect(assigns(:context)).not_to be_nil
        expect(assigns(:context).key?("health")).to be_truthy
        expect(assigns(:context).key?("dental")).to be_truthy
      end
    end
  end

  describe "GET #waiver_receipt" do
    context '#success' do
      let!(:dental_enrollment_update) { dental_enrollment.update_attributes(aasm_state: "coverage_selected", product_id: all_dental_products.first.id)}

      let!(:params) do
        {"health" => {"waiver_enrollment": health_enrollment.id }, "dental" => {"waiver_enrollment": dental_enrollment.id}}
      end

      before do
        sign_in user
        get :waiver_receipt, params
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end
    end
  end
end
