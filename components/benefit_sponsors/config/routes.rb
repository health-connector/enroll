# frozen_string_literal: true

BenefitSponsors::Engine.routes.draw do

  namespace :profiles do
    resources :registrations, :except => [:index] do
      post :counties_for_zip_code, on: :collection
    end

    namespace :broker_agencies do
      resources :broker_agency_profiles, only: [:new, :show, :index, :edit, :update] do
        collection do
          get :family_index
          get :messages
          get :staff_index
          get :agency_messages
          get :commission_statements
        end
        member do
          post :family_datatable
          get :inbox
          get :download_commission_statement
          get :show_commission_statement
        end
      end
      resources :broker_applicants
    end

    namespace :employers do
      resources :employer_profiles, only: [:show] do
        get :export_census_employees
        post :bulk_employee_upload
        get :coverage_reports
        get :estimate_cost
        get :run_eligibility_check
        collection do
          get :generate_sic_tree
          get :show_pending
        end
        member do
          get :inbox
          get :show_invoice if Settings.aca.autopay_enabled
          get :download_invoice
        end

        resources :broker_agency, only: [:index, :show, :create] do
          collection do
            get :active_broker
          end
          get :terminate
        end
      end

      resources :employer_staff_roles do
        member do
          get :approve
        end
      end
    end
  end

  namespace :inboxes do
    resources :messages, only: [:show, :destroy]
  end

  resources :benefit_sponsorships do
    resources :benefit_applications, controller: "benefit_applications/benefit_applications" do
      get 'late_rates_check', on: :collection
      post 'revert'
      post 'submit_application'
      post 'force_submit_application'

      resources :benefit_packages, controller: "benefit_packages/benefit_packages" do
        get :calculate_employer_contributions, on: :collection
        get :calculate_employer_contributions, on: :member
        get :calculate_employee_cost_details, on: :collection
        get :calculate_employee_cost_details, on: :member
        get :reference_product_summary, on: :collection
        member do
          get :estimated_employee_cost_details
        end

        resources :sponsored_benefits, controller: "sponsored_benefits/sponsored_benefits" do
          member do
            get :calculate_employee_cost_details
            get :calculate_employer_contributions
          end

          collection do
            get :calculate_employee_cost_details
            get :calculate_employer_contributions
          end
        end
      end
    end
  end
end
