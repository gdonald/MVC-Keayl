use MVC::Keayl::Routing;

routes {
  root to => 'home#index';

  get '/users', to => 'users#index';
  post '/users', to => 'users#create';

  match '/search', to => 'search#run', via => <get post>;
}
