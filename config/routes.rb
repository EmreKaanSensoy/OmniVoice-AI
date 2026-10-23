Rails.application.routes.draw do
  root "dashboard#index"

  # Session / Switch user
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  post "switch_user/:id", to: "sessions#switch_user", as: :switch_user

  # Dashboard & Analytics
  get "dashboard", to: "dashboard#index"
  get "analytics", to: "analytics#index"

  # Tickets (Zendesk Support)
  resources :tickets do
    resources :comments, controller: "ticket_comments", only: [:create]
    member do
      post :apply_macro
      patch :update_status
      post :trigger_callback
    end
  end

  # Call Center & Microsoft AI (Zendesk Talk)
  get "call_center", to: "call_center#index", as: :call_center
  get "call_center/softphone", to: "call_center#softphone", as: :call_center_softphone
  get "call_center/numbers", to: "call_center#numbers", as: :call_center_numbers
  patch "call_center/update_number", to: "call_center#update_number", as: :call_center_update_number
  post "call_center/custom_incoming_call", to: "call_center#custom_incoming_call", as: :call_center_custom_incoming_call
  post "call_center/simulate_incoming_call", to: "call_center#simulate_incoming_call", as: :simulate_incoming_call
  post "call_center/trigger_ai_analysis/:id", to: "call_center#trigger_ai_analysis", as: :trigger_call_ai_analysis
  get "call_center/token", to: "call_center#token"
  post "call_center/create_from_voice", to: "call_center#create_from_voice", as: :create_from_voice
  post "call_center/webhook", to: "call_center#webhook"

  # Knowledge Base (Zendesk Guide)
  resources :knowledge_articles, path: "guide", only: [:index, :show]

  # Mobile API (Expo Go App)
  namespace :api do
    namespace :v1 do
      namespace :mobile do
        post :voice_ticket
        post :conversational_call
        post :conversational_audio
        get :tickets
        get :check_call
        post :answer_call
        post :end_call
        post :trigger_test_callback
      end
    end
  end

  # Mount ActionCable
  mount ActionCable.server => "/cable"
end
