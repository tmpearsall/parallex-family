Rails.application.routes.draw do
  # No sign-up and no "forgot password" email: accounts and set-password links are issued by an administrator.
  devise_for :users, skip: [ :registrations, :passwords ]
  devise_scope :user do
    get   "set_password/:token" => "set_passwords#edit",   as: :set_password
    patch "set_password/:token" => "set_passwords#update"
  end

  root "home#show"
  get "tree" => "trees#show", as: :tree

  resources :people do
    resources :relationships, only: :create
  end
  resources :relationships, only: :destroy
  resources :households, except: :destroy

  resources :reunions, except: :destroy do
    resources :date_options, only: [ :create, :destroy ] do
      post :vote, on: :member
    end
    resources :rsvps, only: :create
    resources :tasks, only: [ :create, :destroy ] do
      member { patch :claim; patch :unclaim; patch :toggle }
    end
  end

  get    "board"             => "board#index",   as: :board
  post   "board"             => "board#create"
  get    "board/:id"         => "board#show",    as: :board_topic
  post   "board/:id/replies" => "board#reply",   as: :board_replies
  delete "board/:id"         => "board#destroy", as: :board_post
  patch  "board/:id/pin"     => "board#pin",     as: :board_pin

  resource :account, only: [ :edit, :update ]
  namespace :admin do
    resources :users, only: [ :index, :create ] do
      post :link, on: :member
    end
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
