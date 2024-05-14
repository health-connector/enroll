Rails.application.routes.draw do
  mount BenefitSponsors::Engine => "/benefit_sponsors"
  mount SponsoredBenefits::Engine,      at: "/sponsored_benefits"

  devise_for :users

  get "document/employees_template_download" => "documents#employees_template_download", as: :document_employees_template_download
  resources :documents, only: [:destroy] do
    get :product_sbc_download
    get :employer_attestation_document_download
  end

  root "welcome#index"
end
