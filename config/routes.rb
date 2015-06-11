RepMine::Application.routes.draw do  
  
  resources :patterns do
    get :query
    get "translate/:ontology_id", :as => :translate, :to => "patterns#translate"
    post :process_patterns, :on => :collection
    post :combine, :on => :collection
    get :select_combination_nodes, :on => :collection
    post "/save_correspondence/:output_pattern_id", :to => "patterns#save_correspondence", :as => :save_correspondence

    resources :nodes do
      get :fancy_rdf_string
      resources :type_expressions do
        post :add_below
        post :add_same_level
        post :delete
      end
    end

    resources :relation_constraints do
      get :static
    end

    resources :attribute_constraints do
      get :static
    end

    get :missing_concepts, :on => :collection
    get :autocomplete_tag_name, :on => :collection
  end

  resources :repositories do
    get :extract_schema
  end

  resources :ontologies do
    get :autocomplete_ontology_group, :on => :collection
  end

  root :to => "patterns#index"
end
