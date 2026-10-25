Rails.application.routes.draw do
  # No open sign-up and no "forgot password" email: people join a family by invitation.
  devise_for :users, skip: [ :registrations, :passwords ]
  devise_scope :user do
    get   "set_password/:token" => "set_passwords#edit",   as: :set_password
    patch "set_password/:token" => "set_passwords#update"
  end

  resource :account, only: [ :edit, :update ]

  # An invitation link (public, one-time).
  get  "invite/:token"          => "invitations#show",     as: :invitation
  post "invite/:token/accept"   => "invitations#accept",   as: :accept_invitation
  post "invite/:token/register" => "invitations#register", as: :register_invitation

  # Support: create families, password links. Sees no family's data. Multi-tenant mode only.
  unless Instance.dedicated?
    namespace :platform do
      resources :families, only: [ :index, :create ]
      post "password_link" => "users#link", as: :password_link
    end
  end

  # Everything inside one family. The family is looked up through the signed-in user's memberships. In a dedicated
  # instance the prefix is optional and defaults to that one family, so addresses are just "/people", "/tree", ...
  # (a URL whose family equals the default is generated without the prefix).
  family_scope = Instance.dedicated? ? { path: "(/f/:family)", defaults: { family: Instance.family_slug } } : { path: "/f/:family" }
  scope family_scope[:path], **family_scope.slice(:defaults) do
    get "/" => "home#show", as: :family_home
    get "tree" => "trees#show", as: :tree

    resources :people do
      resources :relationships, only: :create
      post :claim, on: :member
    end
    resources :relationships, only: [ :update, :destroy ]
    resources :households, except: :destroy do
      post :add_people, on: :member
    end
    get "directory" => "directory#show", as: :directory
    patch "my_reminders" => "directory#reminders", as: :my_reminders

    get "calendar" => "calendar#index", as: :calendar
    post "calendar/reset_link" => "calendar#reset_link", as: :calendar_reset_link
    resources :events

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
      post :resend, on: :member
    end

    get    "board"             => "board#index",   as: :board
    post   "board"             => "board#create"
    get    "board/:id"         => "board#show",    as: :board_topic
    post   "board/:id/replies" => "board#reply",   as: :board_replies
    delete "board/:id"         => "board#destroy", as: :board_post
    patch  "board/:id/pin"     => "board#pin",     as: :board_pin
  end

  # Stop reminder emails (public, token only).
  get  "unsubscribe/:token" => "unsubscribes#show",   as: :unsubscribe, constraints: { token: /[\w-]+/ }
  post "unsubscribe/:token" => "unsubscribes#create", constraints: { token: /[\w-]+/ }

  # Subscription feed for calendar apps (they cannot sign in): the secret token is the credential.
  get "calendar/:token" => "calendar_feeds#show", as: :calendar_feed, constraints: { token: /[\w-]+/ }, defaults: { format: "ics" }

  root "families#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
