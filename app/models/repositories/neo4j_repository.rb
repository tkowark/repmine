require 'objspace'

class Neo4jRepository < Repository

  attr_accessor :neo

  def self.model_name
    return Repository.model_name
  end
  
  def self.rdf_format
    "rdf"
  end

  def self.default_port
    7474
  end
  
  def self.query_creator_class
    CypherQueryCreator
  end
  
  # queries the graph in order to create an ontology that describes it...
  # 1. Get all nodes with certain labels and determine their properties + value types
  # 2. get all relations between different node types
  def analyze_repository()
    properties = {}
    log_msg("Getting properties per label")
    labels_and_counts.each_pair{|label, count| 
      properties[label] = get_properties(label, count)
      log_status("Finished '#{label}'", 1)
    }
    log_msg("Getting relationships per label")
    populate_ontology!(properties, get_relationships())
    log_status("Finished analyzing the ontology!", 1)
    ontology.update_attributes({:does_exist => true})
    ontology.load_to_dedicated_repository!
  end

  def create_ontology!
    if ontology_creation_job.nil?
      lc = labels_and_counts      
      j = OntologyExtractionJob.new(progress_max: lc.size + 1, repository_id: self.id)
      Delayed::Job.enqueue(j, :queue => ont_creation_queue)
    end
    return nil
  end
  
  def get_properties(label, count)
    offset = sensible_offset(label)
    rounds = (count / offset).to_i
    rounds += 1 if offset.modulo(count) != 0 || count < offset
    log_msg("Getting samples for '#{label}' in #{rounds} rounds.")
    node_properties = {}
    rounds.times do |i|
      log_msg("Collecting samples for '#{label}'. Round #{i+1} of #{rounds}")
      nodes = query_result("MATCH (n:`#{label}`) RETURN n SKIP #{offset * i} LIMIT #{offset}")
      nodes.collect{|node| node.first["data"]}.each{|bh| node_properties.merge!(bh.reject{|k,v| v.nil?})}
    end
    return node_properties
  end

  # we use a sample object to determine how many we should get at once
  def sensible_offset(label)
    (1000000 / ObjectSpace.memsize_of(query_result("MATCH (n:`#{label}`) RETURN n LIMIT 1").first.first)).to_i
  end
  
  # Constructs an OWL ontology...
  def populate_ontology!(properties, relationships)
    properties.each_pair do |label, property_hash|
      owl_class = OwlClass.find_or_create(ontology, label, nil)
      property_hash.each_pair do |property_key, property_sample_value|
        owl_class.add_attribute(property_key, property_sample_value)
      end
    end
    
    # comes in arrays: 0: source, 1: name, 2: target, 3: count
    relationships.each do |relationship|
      domain = OwlClass.find_or_create(ontology, relationship[0], nil)
      range = OwlClass.find_or_create(ontology, relationship[2], nil)
      domain.add_relation(relationship[1], range)
    end
  end
  
  def get_relationships()
    return query_result("MATCH (a)-[r]->(b) RETURN labels(a)[0] AS This, type(r) as To, labels(b)[0] AS That, count(*) AS Count")
  end
  
  def labels_and_counts
    stats = Hash.new(0)
    res = query_result("START n=node(*) RETURN distinct labels(n), count(*)")
    res.each do |labels, count|
      if labels.is_a?(Array)
        labels.each{|label| stats[label] += count}
      else
        stats[labels] += count
      end
    end
    return stats    
  end

  def type_statistics
    return labels_and_counts.to_a
  end
  
  def query_result(query)
    return neo.execute_query(query)["data"]
  end
  
  def neo
    @neo ||= Neography::Rest.new("http://#{host}:#{port}")
  end
  
  def execute(query, generate_csv)
    log_msg("Getting results from repository")
    results = get_all_results(query)
    
    if generate_csv
      return hash_data(results), csv_data(results)
    else
      return hash_data(results)
    end
  end
  
  def csv_data(results)
    CSV.generate do |csv|
      csv << results["columns"]
      results["data"].each{|data_row| csv << data_row}
    end
  end
  
  def hash_data(results)
    return results["data"].collect do |row|
      Hash[ *row.enum_for(:each_with_index).collect{ |val, i| [ results["columns"][i], val ] }.flatten ]
    end
  end
  
  def get_all_results(query)
    results = {"data" => [], "columns" => []}
    i = 0
    
    loop do
      cur_results = neo.execute_query(query + " SKIP #{1000 * i} LIMIT 1000")
      results["data"] += cur_results["data"]
      log_msg("Results so far: #{results["data"].size}")
      results["columns"] = cur_results["columns"]
      break if cur_results["data"].size != 1000
      i += 1
    end
    
    log_status("got a total of #{results["data"].size} records", 75)
    return results
  end
end