Rails.application.routes.draw do
  root 'reps#index'
  resources :reps, only: %i[index show]
end
