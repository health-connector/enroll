Notifier::Engine.routes.draw do
  mount Ckeditor::Engine => '/notifier/ckeditor'

  resources :notice_kinds do
    member do
      get :preview
    end

    collection do
      get :get_tokens
      get :get_placeholders
      post :delete_notices
      post :download_notices
      post :upload_notices
    end
  end
end