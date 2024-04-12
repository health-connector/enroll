IndividualMarket::Engine.routes.draw do
  resources :documents, only: [] do
    collection do
      put :update_verification_type
    end
  end
end
