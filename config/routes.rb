Rails.application.routes.draw do
  # No open sign-up and no "forgot password" email: people join a family by invitation.
  devise_for :users, skip: [ :registrations, :passwords ]
  devise_scope :user do
    get   "set_password/:token" => "set_passwords#edit",   as: :set_password
    patch "set_password/:token" => "set_passwords#update"
  end

  root "families#index"
  resource :account, only: [ :edit, :update ]

  # An invitation link (public, one-time).
  get  "invite/:token"          => "invitations#show",     as: :invitation
  post "invite/:token/accept"   => "invitations#accept",   as: :accept_invitation
  post "invite/:token/register" => "invitations#register", as: :register_invitation

  # Support: create families, password links. Sees no family's data.
  namespace :platform do
    resources :families, only: [ :index, :create ]
    post "password_link" => "users#link", as: :password_link
  end

  # Everything inside one family. The family is looked up through the signed-in user's memberships.
  scope "/f/:family" do
    get "/" => "home#show", as: :family_home
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

    patch "settings" => "settings#update", as: :settings

    resources :members, only: [ :index, :create, :update, :destroy ] do
      delete :revoke, on: :member
    end

    get    "board"             => "board#index",   as: :board
    post   "board"             => "board#create"
    get    "board/:id"         => "board#show",    as: :board_topic
    post   "board/:id/replies" => "board#reply",   as: :board_replies
    delete "board/:id"         => "board#destroy", as: :board_post
    patch  "board/:id/pin"     => "board#pin",     as: :board_pin
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
